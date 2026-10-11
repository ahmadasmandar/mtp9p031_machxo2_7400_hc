library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simple 8N1 UART. A transmit byte is accepted when tx_valid and tx_ready
-- are high on the same rising clock edge. rx_valid pulses for one clock.
entity uart is
    generic (
        G_CLOCK_HZ : positive := 48_000_000;
        G_BAUD     : positive := 1_000_000
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        rx       : in  std_logic;
        tx       : out std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_valid : in  std_logic;
        tx_ready : out std_logic;
        rx_data  : out std_logic_vector(7 downto 0);
        rx_valid : out std_logic
    );
end entity uart;

architecture rtl of uart is
    constant C_TICKS : positive := (G_CLOCK_HZ + G_BAUD / 2) / G_BAUD;
    type t_state is (idle, start_bit, data_bits, stop_bit);

    signal tx_state : t_state := idle;
    signal tx_timer : natural range 0 to C_TICKS - 1 := 0;
    signal tx_index : natural range 0 to 7 := 0;
    signal tx_shift : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg   : std_logic := '1';

    signal rx_meta  : std_logic := '1';
    signal rx_sync  : std_logic := '1';
    signal rx_state : t_state := idle;
    signal rx_timer : natural range 0 to C_TICKS - 1 := 0;
    signal rx_index : natural range 0 to 7 := 0;
    signal rx_shift : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_pulse : std_logic := '0';
begin
    assert C_TICKS >= 4 report "UART clock is too slow for selected baud rate" severity failure;

    tx       <= tx_reg;
    tx_ready <= '1' when tx_state = idle else '0';
    rx_data  <= rx_reg;
    rx_valid <= rx_pulse;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tx_state <= idle;
                tx_timer <= 0;
                tx_index <= 0;
                tx_shift <= (others => '0');
                tx_reg   <= '1';
            else
                case tx_state is
                    when idle =>
                        tx_reg <= '1';
                        if tx_valid = '1' then
                            tx_shift <= tx_data;
                            tx_index <= 0;
                            tx_timer <= C_TICKS - 1;
                            tx_reg   <= '0';
                            tx_state <= start_bit;
                        end if;
                    when start_bit =>
                        if tx_timer = 0 then
                            tx_reg   <= tx_shift(0);
                            tx_timer <= C_TICKS - 1;
                            tx_state <= data_bits;
                        else
                            tx_timer <= tx_timer - 1;
                        end if;
                    when data_bits =>
                        if tx_timer = 0 then
                            tx_timer <= C_TICKS - 1;
                            if tx_index = 7 then
                                tx_reg   <= '1';
                                tx_state <= stop_bit;
                            else
                                tx_index <= tx_index + 1;
                                tx_shift <= '0' & tx_shift(7 downto 1);
                                tx_reg   <= tx_shift(1);
                            end if;
                        else
                            tx_timer <= tx_timer - 1;
                        end if;
                    when stop_bit =>
                        if tx_timer = 0 then
                            tx_state <= idle;
                        else
                            tx_timer <= tx_timer - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            rx_meta  <= rx;
            rx_sync  <= rx_meta;
            rx_pulse <= '0';
            if reset = '1' then
                rx_state <= idle;
                rx_timer <= 0;
                rx_index <= 0;
                rx_shift <= (others => '0');
                rx_reg   <= (others => '0');
            else
                case rx_state is
                    when idle =>
                        if rx_sync = '0' then
                            rx_timer <= C_TICKS / 2 - 1;
                            rx_state <= start_bit;
                        end if;
                    when start_bit =>
                        if rx_timer = 0 then
                            if rx_sync = '0' then
                                rx_timer <= C_TICKS - 1;
                                rx_index <= 0;
                                rx_state <= data_bits;
                            else
                                rx_state <= idle;
                            end if;
                        else
                            rx_timer <= rx_timer - 1;
                        end if;
                    when data_bits =>
                        if rx_timer = 0 then
                            rx_shift(rx_index) <= rx_sync;
                            rx_timer <= C_TICKS - 1;
                            if rx_index = 7 then
                                rx_state <= stop_bit;
                            else
                                rx_index <= rx_index + 1;
                            end if;
                        else
                            rx_timer <= rx_timer - 1;
                        end if;
                    when stop_bit =>
                        if rx_timer = 0 then
                            if rx_sync = '1' then
                                rx_reg   <= rx_shift;
                                rx_pulse <= '1';
                            end if;
                            rx_state <= idle;
                        else
                            rx_timer <= rx_timer - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
