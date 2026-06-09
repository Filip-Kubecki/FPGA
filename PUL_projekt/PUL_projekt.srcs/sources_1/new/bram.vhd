library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bram is
    Port(
        clk   : in  STD_LOGIC;
        -- Port zapisu (ADC)
        we    : in  STD_LOGIC;
        waddr : in  STD_LOGIC_VECTOR(9 downto 0);
        wdata : in  STD_LOGIC_VECTOR(11 downto 0);
        -- Port odczytu (VGA)
        raddr : in  STD_LOGIC_VECTOR(9 downto 0);
        rdata : out STD_LOGIC_VECTOR(11 downto 0)
    );
end bram;

architecture Behavioral of bram is
    type ram_t is array (0 to 639) of STD_LOGIC_VECTOR(11 downto 0);
    signal ram : ram_t := (others => (others => '0'));
begin
    -- Port zapisu
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(waddr))) <= wdata;
            end if;
        end if;
    end process;

    -- Port odczytu
    process(clk)
    begin
        if rising_edge(clk) then
            rdata <= ram(to_integer(unsigned(raddr)));
        end if;
    end process;
end Behavioral;
