library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_camera_uart is
end entity;

architecture sim of tb_top_camera_uart is
    constant C_EXPECTED : string := "I2C 48=1 5D=0 ERR=0" & character'val(13) & character'val(10);
    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal uart_tx   : std_logic;
    signal led       : std_logic;
    signal scl_line  : std_logic := 'H';
    signal sda_line  : std_logic := 'H';
    signal slave_low : std_logic := '0';
begin
    clk <= not clk after 62.5 ns;
    scl_line <= 'H';
    sda_line <= '0' when slave_low = '1' else 'H';

    dut : entity work.top
        generic map (G_CLOCK_HZ => 8_000_000, G_SCAN_INTERVAL => 1000)
        port map (
            pClock => clk, pnReset => reset_n,
            pFPGA_LED_Green => led,
            pFPGA_RX_FTDI => '1', pFPGA_TX_FTDI => uart_tx,
            pKAM_SCLK => scl_line, pKAM_SDATA => sda_line
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
        variable received : std_logic_vector(7 downto 0);
    begin
        wait for 5 us;
        reset_n <= '1';
        for character_index in C_EXPECTED'range loop
            wait until uart_tx'event and uart_tx = '0' for 3 ms;
            assert uart_tx = '0' report "UART report timed out" severity failure;
            wait for 1.5 us;
            for bit_number in 0 to 7 loop
                received(bit_number) := uart_tx;
                wait for 1 us;
            end loop;
            assert received = std_logic_vector(to_unsigned(character'pos(C_EXPECTED(character_index)), 8))
                report "Wrong UART camera scan report" severity failure;
            assert uart_tx = '1' report "UART stop bit missing" severity failure;
        end loop;
        report "TB_TOP_CAMERA_UART_PASS" severity note;
        wait;
    end process;
end architecture;
