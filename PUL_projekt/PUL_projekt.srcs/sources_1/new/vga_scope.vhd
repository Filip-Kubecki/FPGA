library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_scope is
    Port(
        Clock100MHz  : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        enable       : in  STD_LOGIC;
        capture_done : in  STD_LOGIC;
        bram_raddr   : out STD_LOGIC_VECTOR(9 downto 0);
        bram_rdata   : in  STD_LOGIC_VECTOR(11 downto 0);
        VGA_R        : out STD_LOGIC;
        VGA_G        : out STD_LOGIC;
        VGA_B        : out STD_LOGIC;
        VGA_HS       : out STD_LOGIC;
        VGA_VS       : out STD_LOGIC
    );
end vga_scope;

architecture Behavioral of vga_scope is

    component clk_wiz_0 is Port(
            clk_in1  : in  STD_LOGIC;
            clk_out1 : out STD_LOGIC;
            reset    : in  STD_LOGIC;
            locked   : out STD_LOGIC
        );
    end component;

    signal clk25   : STD_LOGIC := '0';
    signal locked  : STD_LOGIC := '0';

    signal h_cnt    : integer range 0 to 799 := 0;
    signal v_cnt    : integer range 0 to 524 := 0;
    signal active   : STD_LOGIC := '0';

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

    signal has_data        : STD_LOGIC := '0';
    signal pixel_threshold : integer range 0 to 479 := 0;

begin

    CLK_WIZ : clk_wiz_0
        port map(
            clk_in1  => Clock100MHz,
            clk_out1 => clk25,
            reset    => reset,
            locked   => locked
        );

    bram_raddr <= STD_LOGIC_VECTOR(to_unsigned(h_cnt, 10))
                  when h_cnt < 640 else (others => '0');

    -- Zapamiętaj że dane są gotowe
    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                has_data <= '0';
            elsif capture_done = '1' then
                has_data <= '1';
            end if;
        end if;
    end process;

    -- Przelicz próg piksela z danych BRAM
    process(clk25)
    begin
        if rising_edge(clk25) then
            pixel_threshold <= to_integer(unsigned(bram_rdata)) * 15 / 256;
        end if;
    end process;

    -- Liczniki H i V
    process(clk25)
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

    -- Rysowanie wykresu
    process(clk25)
    begin
        if rising_edge(clk25) then
            if active = '1' and has_data = '1' then
                if v_cnt >= (V_VISIBLE - pixel_threshold) then
                    VGA_R <= '1';
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
