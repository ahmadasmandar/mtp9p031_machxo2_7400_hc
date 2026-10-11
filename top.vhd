library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    generic (
        G_CLOCK_HZ      : positive := 48_000_000;
        G_SCAN_INTERVAL : positive := G_CLOCK_HZ
    );
    port (
        pClock          : in  std_logic;
        pnReset         : in  std_logic;
        pFPGA_LED_Green : out std_logic;
        pFPGA_RX_FTDI   : in  std_logic;
        pFPGA_TX_FTDI   : out std_logic;
        pKAM_SCLK       : inout std_logic;
        pKAM_SDATA      : inout std_logic
    );
end entity top;

architecture rtl of top is
    constant C_HALF_PERIOD : positive := G_CLOCK_HZ / 2;
    constant C_MESSAGE     : string := "I2C 48=0 5D=0 ERR=0" & character'val(13) & character'val(10);
    signal s_counter       : natural range 0 to C_HALF_PERIOD - 1 := 0;
    signal s_led            : std_logic := '0';
    signal pnReset_c        : std_logic;
    signal s_second_count   : natural range 0 to G_SCAN_INTERVAL - 1 := 0;
    signal s_message_index  : natural range C_MESSAGE'low to C_MESSAGE'high := C_MESSAGE'low;
    signal s_message_active : std_logic := '0';
    signal s_tx_data        : std_logic_vector(7 downto 0);
    signal s_tx_valid       : std_logic;
    signal s_rx_data        : std_logic_vector(7 downto 0);
    signal s_rx_valid       : std_logic;
    signal s_tx_ready       : std_logic;
    signal s_echo_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal s_echo_pending   : std_logic := '0';
    signal s_scan_start     : std_logic := '0';
    signal s_scan_busy      : std_logic;
    signal s_scan_done      : std_logic;
    signal s_ack_48         : std_logic;
    signal s_ack_5d         : std_logic;
    signal s_bus_error      : std_logic;
    signal s_scl_low        : std_logic;
    signal s_sda_low        : std_logic;
begin
    -- The LPF declares pnReset_c as the global reset net.
    pnReset_c <= not pnReset;

    process (pClock)
    begin
        if rising_edge(pClock) then
            if pnReset_c = '1' then
                s_counter <= 0;
                s_led     <= '0';
            elsif s_counter = C_HALF_PERIOD - 1 then
                s_counter <= 0;
                s_led     <= not s_led;
            else
                s_counter <= s_counter + 1;
            end if;
        end if;
    end process;

    pFPGA_LED_Green <= s_led;

    -- Open-drain camera bus: never actively drive either line high.
    pKAM_SCLK  <= '0' when s_scl_low = '1' else 'Z';
    pKAM_SDATA <= '0' when s_sda_low = '1' else 'Z';

    u_camera_scan : entity work.camera_scan
        generic map (G_CLOCK_HZ => G_CLOCK_HZ, G_BUS_HZ => 100_000)
        port map (
            clk => pClock, reset => pnReset_c, start => s_scan_start,
            scl_i => pKAM_SCLK, sda_i => pKAM_SDATA,
            scl_low => s_scl_low, sda_low => s_sda_low,
            busy => s_scan_busy, done => s_scan_done,
            ack_48 => s_ack_48, ack_5d => s_ack_5d,
            bus_error => s_bus_error
        );

    s_tx_data <= x"31" when s_message_active = '1' and s_message_index = 8 and s_ack_48 = '1' else
                 x"31" when s_message_active = '1' and s_message_index = 13 and s_ack_5d = '1' else
                 x"31" when s_message_active = '1' and s_message_index = 19 and s_bus_error = '1' else
                 std_logic_vector(to_unsigned(character'pos(C_MESSAGE(s_message_index)), 8))
                 when s_message_active = '1' else s_echo_data;
    s_tx_valid <= s_message_active or s_echo_pending;

    u_debug_uart : entity work.uart
        generic map (
            G_CLOCK_HZ => G_CLOCK_HZ,
            G_BAUD     => 1_000_000
        )
        port map (
            clk      => pClock,
            reset    => pnReset_c,
            rx       => pFPGA_RX_FTDI,
            tx       => pFPGA_TX_FTDI,
            tx_data  => s_tx_data,
            tx_valid => s_tx_valid,
            tx_ready => s_tx_ready,
            rx_data  => s_rx_data,
            rx_valid => s_rx_valid
        );

    process (pClock)
    begin
        if rising_edge(pClock) then
            if pnReset_c = '1' then
                s_second_count   <= 0;
                s_message_index  <= C_MESSAGE'low;
                s_message_active <= '0';
                s_scan_start <= '0';
                s_echo_data    <= (others => '0');
                s_echo_pending <= '0';
            else
                s_scan_start <= '0';
                if s_second_count = G_SCAN_INTERVAL - 1 then
                    s_second_count   <= 0;
                    if s_scan_busy = '0' and s_message_active = '0' then
                        s_scan_start <= '1';
                    end if;
                else
                    s_second_count <= s_second_count + 1;
                end if;

                if s_scan_done = '1' then
                    s_message_index  <= C_MESSAGE'low;
                    s_message_active <= '1';
                end if;

                if s_tx_ready = '1' then
                    if s_message_active = '1' then
                        if s_message_index = C_MESSAGE'high then
                            s_message_active <= '0';
                        else
                            s_message_index <= s_message_index + 1;
                        end if;
                    elsif s_echo_pending = '1' then
                        s_echo_pending <= '0';
                    end if;
                end if;
                if s_rx_valid = '1' then
                    s_echo_data    <= s_rx_data;
                    s_echo_pending <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
