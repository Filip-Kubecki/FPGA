library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_scope is
    Port(
        Clock100MHz  : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        enable       : in  STD_LOGIC;
        capture_done : in  STD_LOGIC;
        decimation   : in  STD_LOGIC_VECTOR(2 downto 0);
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

    -- Grid constants
    constant GRID_H : integer := 29;
    constant GRID_V : integer := 64;

    signal has_data        : STD_LOGIC := '0';
    signal pixel_threshold : integer range 0 to 479 := 0;

    constant CHAR_W      : integer := 5;
    constant CHAR_H      : integer := 7;
    constant CHAR_GAP    : integer := 1;
    constant CHAR_SCALE  : integer := 2;
    constant LABEL_X0    : integer := 8;
    constant LABEL_Y0    : integer := 12;
    constant LABEL_LEN   : integer := 11;

    -- Kody znakow
    constant CH_0     : integer := 0;
    constant CH_1     : integer := 1;
    constant CH_D     : integer := 2;
    constant CH_I     : integer := 3;
    constant CH_N     : integer := 4;
    constant CH_S     : integer := 5;
    constant CH_V     : integer := 6;
    constant CH_SLASH : integer := 7;
    constant CH_2     : integer := 8;
    constant CH_4     : integer := 9;
    constant CH_5     : integer := 10;
    constant CH_6     : integer := 11;
    constant CH_8     : integer := 12;
    constant CH_DOT   : integer := 13;
    constant CH_M     : integer := 14;
    constant CH_U     : integer := 15;
    constant CH_SPACE : integer := 16;

    type char_array_t is array (0 to LABEL_LEN - 1) of integer range 0 to 16;
    type label_set_t is array (0 to 5) of char_array_t;

    constant LABEL_SET : label_set_t := (
        0 => (CH_6, CH_4, CH_0, CH_U, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE, CH_SPACE),
        1 => (CH_1, CH_DOT, CH_2, CH_8, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE),
        2 => (CH_2, CH_DOT, CH_5, CH_6, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE),
        3 => (CH_5, CH_DOT, CH_1, CH_2, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE),
        4 => (CH_1, CH_0, CH_DOT, CH_2, CH_4, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V),
        5 => (CH_2, CH_0, CH_DOT, CH_4, CH_8, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V)
    );

    type font_rom_t is array (0 to 16) of STD_LOGIC_VECTOR(0 to CHAR_H * CHAR_W - 1);
    constant FONT_ROM : font_rom_t := (
        CH_0     => "01110" & "10001" & "10011" & "10101" & "11001" & "10001" & "01110",
        CH_1     => "00100" & "01100" & "00100" & "00100" & "00100" & "00100" & "01110",
        CH_D     => "00001" & "00001" & "01101" & "10011" & "10001" & "10011" & "01101",
        CH_I     => "00100" & "00000" & "01100" & "00100" & "00100" & "00100" & "01110",
        CH_N     => "00000" & "00000" & "11010" & "10101" & "10101" & "10101" & "10101",
        CH_S     => "00000" & "00000" & "01111" & "10000" & "01110" & "00001" & "11110",
        CH_V     => "00000" & "00000" & "10001" & "10001" & "10001" & "01010" & "00100",
        CH_SLASH => "00001" & "00001" & "00010" & "00100" & "01000" & "10000" & "10000",
        CH_2     => "01110" & "10001" & "00001" & "00010" & "00100" & "01000" & "11111",
        CH_4     => "00010" & "00110" & "01010" & "10010" & "11111" & "00010" & "00010",
        CH_5     => "11111" & "10000" & "11110" & "00001" & "00001" & "10001" & "01110",
        CH_6     => "00110" & "01000" & "10000" & "10110" & "10001" & "10001" & "01110",
        CH_8     => "01110" & "10001" & "10001" & "01110" & "10001" & "10001" & "01110",
        CH_DOT   => "00000" & "00000" & "00000" & "00000" & "00000" & "01100" & "01100",
        CH_M     => "00000" & "00000" & "11010" & "10101" & "10101" & "10101" & "10101",
        CH_U     => "00000" & "00000" & "10001" & "10001" & "10001" & "10001" & "01110",
        CH_SPACE => "00000" & "00000" & "00000" & "00000" & "00000" & "00000" & "00000"
    );

    signal label_pixel : STD_LOGIC := '0';

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

    -- Data ready
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

    process(clk25)
    begin
        if rising_edge(clk25) then
            pixel_threshold <= to_integer(unsigned(bram_rdata)) * 15 / 256;
        end if;
    end process;

    -- H and V counter
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

    --------------------------------------------------------------------
    -- Generowanie pikseli etykiety podstawy czasu
    --------------------------------------------------------------------
    process(h_cnt, v_cnt, decimation)
        variable rel_x         : integer;
        variable rel_y         : integer;
        variable char_idx      : integer;
        variable col_in_ch     : integer;
        variable row_in_ch     : integer;
        variable bit_idx       : integer;
        variable label_w       : integer;
        variable label_h       : integer;
        variable inside_lbl    : boolean;
        variable pix           : STD_LOGIC;
        variable dec_idx       : integer range 0 to 5;
        variable current_label : char_array_t;
    begin
        label_w := LABEL_LEN * (CHAR_W + CHAR_GAP) * CHAR_SCALE;
        label_h := CHAR_H * CHAR_SCALE;

        pix := '0';

        dec_idx := to_integer(unsigned(decimation));
        if dec_idx > 5 then
            dec_idx := 5;
        end if;
        current_label := LABEL_SET(dec_idx);

        inside_lbl := (h_cnt >= LABEL_X0) and (h_cnt < LABEL_X0 + label_w) and
                      (v_cnt >= LABEL_Y0) and (v_cnt < LABEL_Y0 + label_h);

        if inside_lbl then
            rel_x := h_cnt - LABEL_X0;
            rel_y := v_cnt - LABEL_Y0;

            char_idx  := rel_x / ((CHAR_W + CHAR_GAP) * CHAR_SCALE);
            col_in_ch := (rel_x mod ((CHAR_W + CHAR_GAP) * CHAR_SCALE)) / CHAR_SCALE;
            row_in_ch := rel_y / CHAR_SCALE;

            if char_idx < LABEL_LEN and col_in_ch < CHAR_W then
                bit_idx := row_in_ch * CHAR_W + col_in_ch;
                pix := FONT_ROM(current_label(char_idx))(bit_idx);
            end if;
        end if;

        label_pixel <= pix;
    end process;

    -- Ploting (data, grid, label)
    process(clk25)
        variable on_grid_h : boolean;
        variable on_grid_v : boolean;
        variable on_signal : boolean;
    begin
        if rising_edge(clk25) then
            if active = '1' then
                on_grid_h := ((V_VISIBLE - 1 - v_cnt) mod GRID_H) = 0;
                on_grid_v := (h_cnt mod GRID_V) = 0;

                on_signal := has_data = '1' and
                             v_cnt >= (V_VISIBLE - pixel_threshold);

                if label_pixel = '1' then
                    VGA_R <= '0';
                    VGA_G <= '1';
                    VGA_B <= '0';
                elsif on_signal then
                    VGA_R <= '1';
                    VGA_G <= '1';
                    VGA_B <= '0';
                elsif on_grid_h or on_grid_v then
                    VGA_R <= '1';
                    VGA_G <= '1';
                    VGA_B <= '1';
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
end Behavioral;
