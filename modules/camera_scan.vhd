library ieee;
use ieee.std_logic_1164.all;

-- Probe only the two documented MT9P031 SADDR choices. An ACK is not yet
-- proof of sensor identity; register readback is a later bring-up step.
entity camera_scan is
    generic (
        G_CLOCK_HZ : positive := 48_000_000;
        G_BUS_HZ   : positive := 100_000
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        start     : in  std_logic;
        scl_i     : in  std_logic;
        sda_i     : in  std_logic;
        scl_low   : out std_logic;
        sda_low   : out std_logic;
        busy      : out std_logic;
        done      : out std_logic;
        ack_48    : out std_logic;
        ack_5d    : out std_logic;
        bus_error : out std_logic
    );
end entity;

architecture rtl of camera_scan is
    type t_state is (idle, launch_48, wait_48, gap, launch_5d, wait_5d);
    signal state       : t_state := idle;
    signal probe_start : std_logic := '0';
    signal probe_done  : std_logic;
    signal probe_ack   : std_logic;
    signal probe_error : std_logic;
    signal address     : std_logic_vector(6 downto 0) := "1001000";
    signal ack48_reg   : std_logic := '0';
    signal ack5d_reg   : std_logic := '0';
    signal error_reg   : std_logic := '0';
    signal done_reg    : std_logic := '0';
    signal gap_count   : natural range 0 to G_CLOCK_HZ / 1000 := 0;
begin
    busy      <= '0' when state = idle else '1';
    done      <= done_reg;
    ack_48    <= ack48_reg;
    ack_5d    <= ack5d_reg;
    bus_error <= error_reg;

    u_probe : entity work.i2c_probe
        generic map (G_CLOCK_HZ => G_CLOCK_HZ, G_BUS_HZ => G_BUS_HZ)
        port map (
            clk => clk, reset => reset, start => probe_start,
            address => address, scl_i => scl_i, sda_i => sda_i,
            scl_low => scl_low, sda_low => sda_low,
            busy => open, done => probe_done, ack => probe_ack,
            bus_error => probe_error
        );

    process (clk)
    begin
        if rising_edge(clk) then
            probe_start <= '0';
            done_reg <= '0';
            if reset = '1' then
                state <= idle;
                address <= "1001000";
                ack48_reg <= '0';
                ack5d_reg <= '0';
                error_reg <= '0';
                gap_count <= 0;
            else
                case state is
                    when idle =>
                        if start = '1' then
                            ack48_reg <= '0';
                            ack5d_reg <= '0';
                            error_reg <= '0';
                            address <= "1001000"; -- 0x48
                            state <= launch_48;
                        end if;
                    when launch_48 =>
                        probe_start <= '1';
                        state <= wait_48;
                    when wait_48 =>
                        if probe_done = '1' then
                            ack48_reg <= probe_ack;
                            error_reg <= probe_error;
                            if probe_error = '1' then
                                done_reg <= '1';
                                state <= idle;
                            else
                                gap_count <= 0;
                                state <= gap;
                            end if;
                        end if;
                    when gap =>
                        -- Allow the previous STOP and synchronizers to settle.
                        if gap_count = G_CLOCK_HZ / 1000 then
                            address <= "1011101"; -- 0x5D
                            state <= launch_5d;
                        else
                            gap_count <= gap_count + 1;
                        end if;
                    when launch_5d =>
                        probe_start <= '1';
                        state <= wait_5d;
                    when wait_5d =>
                        if probe_done = '1' then
                            ack5d_reg <= probe_ack;
                            error_reg <= probe_error;
                            done_reg <= '1';
                            state <= idle;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
