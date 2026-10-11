library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c_probe is
end entity;

architecture sim of tb_i2c_probe is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal start     : std_logic := '0';
    signal address   : std_logic_vector(6 downto 0) := (others => '0');
    signal scl_low   : std_logic;
    signal sda_low   : std_logic;
    signal scl_line  : std_logic := 'H';
    signal sda_line  : std_logic := 'H';
    signal slave_low : std_logic := '0';
    signal stuck_scl : std_logic := '0';
    signal busy      : std_logic;
    signal done      : std_logic;
    signal ack       : std_logic;
    signal bus_error : std_logic;
begin
    clk <= not clk after 500 ns;
    scl_line <= '0' when scl_low = '1' or stuck_scl = '1' else 'H';
    sda_line <= '0' when sda_low = '1' or slave_low = '1' else 'H';

    dut : entity work.i2c_probe
        generic map (G_CLOCK_HZ => 1_000_000, G_BUS_HZ => 100_000)
        port map (
            clk => clk, reset => reset, start => start, address => address,
            scl_i => scl_line, sda_i => sda_line,
            scl_low => scl_low, sda_low => sda_low,
            busy => busy, done => done, ack => ack, bus_error => bus_error
        );

    slave : process
    begin
        -- First transaction: acknowledge the address on the ninth clock.
        wait until sda_line'event and to_x01(sda_line) = '0' and to_x01(scl_line) = '1';
        for bit_number in 1 to 9 loop
            wait until scl_line'event and to_x01(scl_line) = '0';
        end loop;
        slave_low <= '1';
        wait until scl_line'event and to_x01(scl_line) = '0';
        slave_low <= '0';
        wait;
    end process;

    protocol_monitor : process
        variable expected_byte : std_logic_vector(7 downto 0);
    begin
        for transaction in 0 to 1 loop
            if transaction = 0 then
                expected_byte := x"90"; -- 0x48 plus the write bit
            else
                expected_byte := x"BA"; -- 0x5D plus the write bit
            end if;

            wait until sda_line'event and to_x01(sda_line) = '0'
                       and to_x01(scl_line) = '1';
            for bit_number in 7 downto 0 loop
                wait until scl_line'event and to_x01(scl_line) = '1';
                assert to_x01(sda_line) = expected_byte(bit_number)
                    report "Incorrect I2C address/write bit" severity failure;
            end loop;
            -- The ninth rising edge clocks the slave ACK/NACK.
            wait until scl_line'event and to_x01(scl_line) = '1';
            wait until sda_line'event and to_x01(sda_line) = '1';
            assert to_x01(scl_line) = '1'
                report "STOP was not issued with SCL high" severity failure;
        end loop;
        wait;
    end process;

    stimulus : process
    begin
        wait for 5 us;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 5 us;
        address <= std_logic_vector(to_unsigned(16#48#, 7));
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1' for 500 us;
        assert done = '1' report "ACK probe timed out" severity failure;
        assert ack = '1' and bus_error = '0'
            report "ACK probe failed" severity failure;

        wait for 10 us;
        address <= std_logic_vector(to_unsigned(16#5D#, 7));
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1' for 500 us;
        assert done = '1' report "NACK probe timed out" severity failure;
        assert ack = '0' and bus_error = '0'
            report "NACK probe failed" severity failure;

        wait for 10 us;
        stuck_scl <= '1';
        wait for 5 us;
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1' for 20 us;
        assert done = '1' and bus_error = '1' and busy = '0'
            report "Stuck-bus detection failed" severity failure;
        assert scl_low = '0' and sda_low = '0'
            report "Stuck-bus path did not release pins" severity failure;

        report "TB_I2C_PROBE_PASS" severity note;
        wait;
    end process;
end architecture;
