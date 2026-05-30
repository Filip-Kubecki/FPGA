library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port(
        -- CLK and control
        Clock100MHz : in  STD_LOGIC;
        SW          : in  STD_LOGIC_VECTOR(3 downto 0);
        -- ADC
        ADC_CLK     : out STD_LOGIC;
        ADC_CS      : out STD_LOGIC;
        ADC_DOUT    : in  STD_LOGIC;
        -- VGA
        VGA_R       : out STD_LOGIC;
        VGA_G       : out STD_LOGIC;
        VGA_B       : out STD_LOGIC;
        VGA_HS      : out STD_LOGIC;
        VGA_VS      : out STD_LOGIC;
        
        -- LED - debug
        LED         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end top;

architecture Behavioral of top is

    component adc_reader is
        Port(
            Clock100MHz : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            enable      : in  STD_LOGIC;
            ADC_CLK     : out STD_LOGIC;
            ADC_CS      : out STD_LOGIC;
            ADC_DOUT    : in  STD_LOGIC;
            data_out    : out STD_LOGIC_VECTOR(11 downto 0);
            data_valid  : out STD_LOGIC
        );
    end component;

    component vga_bar is
        Port(
            Clock100MHz : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            enable      : in  STD_LOGIC;
            adc_data    : in  STD_LOGIC_VECTOR(11 downto 0);
            VGA_R       : out STD_LOGIC;
            VGA_G       : out STD_LOGIC;
            VGA_B       : out STD_LOGIC;
            VGA_HS      : out STD_LOGIC;
            VGA_VS      : out STD_LOGIC
        );
    end component;

    signal reset      : STD_LOGIC;
    signal adc_en     : STD_LOGIC;
    signal vga_en     : STD_LOGIC;

    signal adc_data   : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal adc_valid  : STD_LOGIC := '0';

    constant THRESH_1V  : unsigned(11 downto 0) := to_unsigned(999,  12);
    constant THRESH_2V  : unsigned(11 downto 0) := to_unsigned(1998, 12);
    constant THRESH_3V  : unsigned(11 downto 0) := to_unsigned(2997, 12);
    constant THRESH_35V : unsigned(11 downto 0) := to_unsigned(3496, 12);

begin

    reset  <= SW(0); -- RESET
    adc_en <= SW(1); -- ADC ENABLE
    vga_en <= SW(2); -- VGA ENABLE

    LED_INDICATOR : process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                LED <= (others => '0');
            elsif adc_valid = '1' then
                LED(0) <= '1' when unsigned(adc_data) > THRESH_1V  else '0';
                LED(1) <= '1' when unsigned(adc_data) > THRESH_2V  else '0';
                LED(2) <= '1' when unsigned(adc_data) > THRESH_3V  else '0';
                LED(3) <= '1' when unsigned(adc_data) > THRESH_35V else '0';
            end if;
        end if;
    end process;

    U_ADC : adc_reader
        port map(
            Clock100MHz => Clock100MHz,
            reset       => reset,
            enable      => adc_en,
            ADC_CLK     => ADC_CLK,
            ADC_CS      => ADC_CS,
            ADC_DOUT    => ADC_DOUT,
            data_out    => adc_data,
            data_valid  => adc_valid
        );

    U_VGA : vga_bar
        port map(
            Clock100MHz => Clock100MHz,
            reset       => reset,
            enable      => vga_en,
            adc_data    => adc_data,
            VGA_R       => VGA_R,
            VGA_G       => VGA_G,
            VGA_B       => VGA_B,
            VGA_HS      => VGA_HS,
            VGA_VS      => VGA_VS
        );

end Behavioral;
