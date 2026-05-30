library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_bar is
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
end vga_bar;

architecture Behavioral of vga_bar is

    signal clk25  : STD_LOGIC := '0';
    signal h_cnt  : integer range 0 to 799 := 0;
    signal v_cnt  : integer range 0 to 524 := 0;
    signal active : STD_LOGIC := '0';

    constant H_VISIBLE : integer := 640;
    constant H_FRONT   : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BACK    : integer := 48;
    constant H_TOTAL   : integer := 800;

    constant V_VISIBLE : integer := 480;
    constant V_FRONT   : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BACK    : integer := 33;
    constant V_TOTAL   : integer := 525;

    -- Grubość paska w pikselach
    constant BAR_HEIGHT : integer := 460;

    -- Szerokość paska obliczona z ADC: (adc_data * 640) / 4096
    signal bar_width : integer range 0 to 640 := 0;

begin

    -- Dzielnik 100MHz -> 25MHz
    CLK_DIVIDER : process(Clock100MHz)
        variable cnt : integer range 0 to 1 := 0;
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                cnt   := 0;
                clk25 <= '0';
            else
                if cnt = 1 then
                    cnt   := 0;
                    clk25 <= not clk25;
                else
                    cnt := cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Przelicz szerokość paska z ADC
    BAR_WIDTH : process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                bar_width <= 0;
            else
                bar_width <= to_integer(unsigned(adc_data)) * 5 / 32;
            end if;
        end if;
    end process;

    -- Liczniki H i V
    HV_CONTER : process(clk25)
    begin
        if rising_edge(clk25) then
            if reset = '1' then
                h_cnt <= 0;
                v_cnt <= 0;
            elsif enable = '1' then
                if h_cnt = H_TOTAL - 1 then
                    h_cnt <= 0;
                    if v_cnt = V_TOTAL - 1 then
                        v_cnt <= 0;
                    else
                        v_cnt <= v_cnt + 1;
                    end if;
                else
                    h_cnt <= h_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Sync
    VGA_HS <= '0' when (reset = '0' and enable = '1') and
                       (h_cnt >= H_VISIBLE + H_FRONT) and
                       (h_cnt <  H_VISIBLE + H_FRONT + H_SYNC)
              else '1';

    VGA_VS <= '0' when (reset = '0' and enable = '1') and
                       (v_cnt >= V_VISIBLE + V_FRONT) and
                       (v_cnt <  V_VISIBLE + V_FRONT + V_SYNC)
              else '1';

    active <= '1' when (reset = '0' and enable = '1') and
                       (h_cnt < H_VISIBLE) and
                       (v_cnt < V_VISIBLE)
              else '0';

    -- Rysowanie paska
    DRAW_BAR : process(clk25)
    begin
        if rising_edge(clk25) then
            if active = '1' and v_cnt < BAR_HEIGHT then
                -- Białe linie co 0.5V
                if (h_cnt mod 78) < 2 then
                    VGA_R <= '1';
                    VGA_G <= '1';
                    VGA_B <= '1';
                -- Zielony pasek ADC
                elsif h_cnt < bar_width then
                    VGA_R <= '0';
                    VGA_G <= '1';
                    VGA_B <= '0';
                else
                    VGA_R <= '0';
                    VGA_G <= '0';
                    VGA_B <= '0';
                end if;
            else
                VGA_R <= '0';
                VGA_G <= '0';
                VGA_B <= '0';
            end if;
        end if;
    end process;
end Behavioral;
