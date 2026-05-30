library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port(
        Clock100MHz : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        enable      : in  STD_LOGIC;
        VGA_R       : out STD_LOGIC;
        VGA_G       : out STD_LOGIC;
        VGA_B       : out STD_LOGIC;
        VGA_HS      : out STD_LOGIC;
        VGA_VS      : out STD_LOGIC
    );
end vga_controller;

architecture Behavioral of vga_controller is

    signal clk25    : STD_LOGIC := '0';

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

    signal h_cnt    : integer range 0 to H_TOTAL - 1 := 0;
    signal v_cnt    : integer range 0 to V_TOTAL - 1 := 0;
    signal active   : STD_LOGIC := '0';
    signal stripe   : STD_LOGIC_VECTOR(2 downto 0) := (others => '0');

begin

    process(Clock100MHz)
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

    -- Numer paska
    process(h_cnt)
    begin
        if    h_cnt < 80  then stripe <= "000";
        elsif h_cnt < 160 then stripe <= "001";
        elsif h_cnt < 240 then stripe <= "010";
        elsif h_cnt < 320 then stripe <= "011";
        elsif h_cnt < 400 then stripe <= "100";
        elsif h_cnt < 480 then stripe <= "101";
        elsif h_cnt < 560 then stripe <= "110";
        else                   stripe <= "111";
        end if;
    end process;

    VGA_R <= stripe(2) and active;
    VGA_G <= stripe(1) and active;
    VGA_B <= stripe(0) and active;

end Behavioral;
