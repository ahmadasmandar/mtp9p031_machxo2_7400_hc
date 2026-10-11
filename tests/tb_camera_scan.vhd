library ieee;
use ieee.std_logic_1164.all;

entity tb_camera_scan is
end entity;

architecture sim of tb_camera_scan is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal start     : std_logic := '0';
    signal scl_low   : std_logic;
    signal sda_low   : std_logic;
    signal scl_line  : std_logic := 'H';
    signal sda_line  : std_logic := 'H';
    signal slave_low : std_logic := '0';
    signal busy      : std_logic;
    signal done      : std_logic;
    signal ack_48    : std_logic;
    signal ack_5d    : std_logic;
    signal bus_error : std_logic;
begin
    clk <= not clk after 500 ns;
    scl_line <= '0' when scl_low = '1' else 'H';
    sda_line <= '0' when sda_low = '1' or slave_low = '1' else 'H';

    dut : entity work.camera_scan
        generic map (G_CLOCK_HZ => 1_000_000, G_BUS_HZ => 100_000)
        port map (
            clk => clk, reset => reset, start => start,
            scl_i => scl_line, sda_i => sda_line,
            scl_low => scl_low, sda_low => sda_low,
            busy => busy, done => done,
            ack_48 => ack_48, ack_5d => ack_5d, bus_error => bus_error
        );

    slave : process
    begin
        wait until sda_line'event and to_x01(sda_line) = '0'
                   and to_x01(scl_line) = '1';
        for bit_number in 1 to 9 loop
            wait until scl_line'event and to_x01(scl_line) = '0';
        end loop;
        slave_low <= '1';
        wait until scl_line'event and to_x01(scl_line) = '0';
        slave_low <= '0';
        wait;
    end process;

    stimulus : process
    begin
        wait for 5 us;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 5 us;
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1' for 2 ms;
        assert done = '1' report "Camera scan timed out" severity failure;
        assert ack_48 = '1' and ack_5d = '0' and bus_error = '0'
            report "Unexpected camera address scan result" severity failure;
        report "TB_CAMERA_SCAN_PASS" severity note;
        wait;
    end process;
end architecture;
