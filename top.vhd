library ieee;
use ieee.std_logic_1164.all;

entity top is
    generic (
        G_CLOCK_HZ : positive := 48_000_000
    );
    port (
        pClock          : in  std_logic;
        pnReset         : in  std_logic;
        pFPGA_LED_Green : out std_logic
    );
end entity top;

architecture rtl of top is
    constant C_HALF_PERIOD : positive := G_CLOCK_HZ / 2;
    signal s_counter       : natural range 0 to C_HALF_PERIOD - 1 := 0;
    signal s_led            : std_logic := '0';
    signal pnReset_c        : std_logic;
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
end architecture rtl;
