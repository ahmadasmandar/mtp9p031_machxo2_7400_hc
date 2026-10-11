library ieee;
use ieee.std_logic_1164.all;

-- Address-only two-wire probe. SCL and SDA outputs only pull low or release;
-- external pull-ups are required. One start pulse sends address + write bit,
-- samples the ninth-clock ACK, then issues STOP and pulses done.
entity i2c_probe is
    generic (
        G_CLOCK_HZ : positive := 48_000_000;
        G_BUS_HZ   : positive := 100_000
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        start     : in  std_logic;
        address   : in  std_logic_vector(6 downto 0);
        scl_i     : in  std_logic;
        sda_i     : in  std_logic;
        scl_low   : out std_logic;
        sda_low   : out std_logic;
        busy      : out std_logic;
        done      : out std_logic;
        ack       : out std_logic;
        bus_error : out std_logic
    );
end entity i2c_probe;

architecture rtl of i2c_probe is
    constant C_HALF_TICKS : positive := G_CLOCK_HZ / (2 * G_BUS_HZ);
    type t_state is (idle, start_hold, bit_low, bit_high,
                     ack_low, ack_high, stop_low, stop_high);
    signal state       : t_state := idle;
    signal timer       : natural range 0 to C_HALF_TICKS - 1 := 0;
    signal bit_index   : natural range 0 to 7 := 7;
    signal address_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal scl_drive   : std_logic := '0';
    signal sda_drive   : std_logic := '0';
    signal scl_meta    : std_logic := '1';
    signal scl_sync    : std_logic := '1';
    signal sda_meta    : std_logic := '1';
    signal sda_sync    : std_logic := '1';
    signal done_reg    : std_logic := '0';
    signal ack_reg     : std_logic := '0';
    signal error_reg   : std_logic := '0';
begin
    assert C_HALF_TICKS >= 3
        report "I2C system clock is too slow for selected bus rate" severity failure;

    scl_low   <= scl_drive;
    sda_low   <= sda_drive;
    busy      <= '0' when state = idle else '1';
    done      <= done_reg;
    ack       <= ack_reg;
    bus_error <= error_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            scl_meta <= to_x01(scl_i);
            scl_sync <= scl_meta;
            sda_meta <= to_x01(sda_i);
            sda_sync <= sda_meta;
            done_reg <= '0';

            if reset = '1' then
                state        <= idle;
                timer        <= 0;
                bit_index    <= 7;
                address_byte <= (others => '0');
                scl_drive    <= '0';
                sda_drive    <= '0';
                ack_reg      <= '0';
                error_reg    <= '0';
            else
                case state is
                    when idle =>
                        if start = '1' then
                            ack_reg   <= '0';
                            error_reg <= '0';
                            if scl_sync = '1' and sda_sync = '1' then
                                address_byte <= address & '0';
                                bit_index    <= 7;
                                sda_drive    <= '1'; -- START while SCL is high
                                timer        <= C_HALF_TICKS - 1;
                                state        <= start_hold;
                            else
                                error_reg <= '1';
                                done_reg  <= '1';
                            end if;
                        end if;

                    when start_hold =>
                        if timer = 0 then
                            scl_drive <= '1';
                            sda_drive <= not address_byte(7);
                            timer     <= C_HALF_TICKS - 1;
                            state     <= bit_low;
                        else
                            timer <= timer - 1;
                        end if;

                    when bit_low =>
                        if timer = 0 then
                            scl_drive <= '0';
                            timer     <= C_HALF_TICKS - 1;
                            state     <= bit_high;
                        else
                            timer <= timer - 1;
                        end if;

                    when bit_high =>
                        if timer = 0 then
                            if scl_sync /= '1' then
                                scl_drive <= '0';
                                sda_drive <= '0';
                                error_reg <= '1';
                                done_reg  <= '1';
                                state     <= idle;
                            else
                                scl_drive <= '1';
                                timer     <= C_HALF_TICKS - 1;
                                if bit_index = 0 then
                                    sda_drive <= '0'; -- release for slave ACK
                                    state     <= ack_low;
                                else
                                    bit_index <= bit_index - 1;
                                    sda_drive <= not address_byte(bit_index - 1);
                                    state     <= bit_low;
                                end if;
                            end if;
                        else
                            timer <= timer - 1;
                        end if;

                    when ack_low =>
                        if timer = 0 then
                            scl_drive <= '0';
                            timer     <= C_HALF_TICKS - 1;
                            state     <= ack_high;
                        else
                            timer <= timer - 1;
                        end if;

                    when ack_high =>
                        if timer = 0 then
                            if scl_sync /= '1' then
                                scl_drive <= '0';
                                sda_drive <= '0';
                                error_reg <= '1';
                                done_reg  <= '1';
                                state     <= idle;
                            else
                                ack_reg   <= not sda_sync;
                                scl_drive <= '1';
                                sda_drive <= '1'; -- prepare STOP while SCL is low
                                timer     <= C_HALF_TICKS - 1;
                                state     <= stop_low;
                            end if;
                        else
                            timer <= timer - 1;
                        end if;

                    when stop_low =>
                        if timer = 0 then
                            scl_drive <= '0';
                            timer     <= C_HALF_TICKS - 1;
                            state     <= stop_high;
                        else
                            timer <= timer - 1;
                        end if;

                    when stop_high =>
                        if timer = 0 then
                            sda_drive <= '0'; -- STOP while SCL is high
                            if scl_sync /= '1' then
                                error_reg <= '1';
                            end if;
                            done_reg <= '1';
                            state    <= idle;
                        else
                            timer <= timer - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
