--------------------------------------------------------------------------------
-- moving_average_filter.vhd
--
-- 8-tap moving average filter (FIR) for smoothing the raw ADC signal.
-- The last 8 samples are kept in a shift register; their sum is divided
-- by 8 via a bit shift, avoiding the need for a hardware divider.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter is
    Port(
        Clock100MHz : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        adc_data    : in  STD_LOGIC_VECTOR(11 downto 0);
        adc_valid   : in  STD_LOGIC;
        avg_out     : out STD_LOGIC_VECTOR(11 downto 0);
        avg_valid   : out STD_LOGIC
    );
end moving_average_filter;

architecture Behavioral of moving_average_filter is
    type avg_buf_t is array (0 to 7) of unsigned(11 downto 0);
    signal avg_buf : avg_buf_t := (others => (others => '0'));
    signal avg_sum : unsigned(14 downto 0) := (others => '0');
begin

    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                avg_buf   <= (others => (others => '0'));
                avg_sum   <= (others => '0');
                avg_out   <= (others => '0');
                avg_valid <= '0';
            elsif adc_valid = '1' then
                -- Shift in new sample, sum all 8, divide by 8 (>>3)
                avg_buf(1 to 7) <= avg_buf(0 to 6);
                avg_buf(0)      <= unsigned(adc_data);
                avg_sum <= resize(avg_buf(0), 15) + resize(avg_buf(1), 15) +
                           resize(avg_buf(2), 15) + resize(avg_buf(3), 15) +
                           resize(avg_buf(4), 15) + resize(avg_buf(5), 15) +
                           resize(avg_buf(6), 15) + resize(avg_buf(7), 15);
                avg_out   <= STD_LOGIC_VECTOR(avg_sum(14 downto 3));
                avg_valid <= '1';
            else
                avg_valid <= '0';
            end if;
        end if;
    end process;

end Behavioral;
