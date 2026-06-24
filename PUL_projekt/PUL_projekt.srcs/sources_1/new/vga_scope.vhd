--------------------------------------------------------------------------------
-- vga_scope.vhd
--
-- VGA display controller for the oscilloscope front end. Generates a
-- standard 640x480@60Hz VGA timing signal, draws a measurement grid,
-- overlays the captured waveform read out of the BRAM frame buffer, and
-- renders a text label showing the current time/division setting using
-- a small built-in bitmap font.
--------------------------------------------------------------------------------
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

    -- Clocking Wizard IP: derives the 25 MHz pixel clock required for
    -- 640x480@60Hz VGA timing from the 100 MHz system clock.
    component clk_wiz_0 is Port(
            clk_in1  : in  STD_LOGIC;
            clk_out1 : out STD_LOGIC;
            reset    : in  STD_LOGIC;
            locked   : out STD_LOGIC
        );
    end component;

    signal clk25   : STD_LOGIC := '0';
    signal locked  : STD_LOGIC := '0';

    -- Pixel-clock-domain horizontal/vertical counters driving VGA timing
    signal h_cnt    : integer range 0 to 799 := 0;
    signal v_cnt    : integer range 0 to 524 := 0;
    -- High during the visible (active) drawing region of the frame
    signal active   : STD_LOGIC := '0';

    -- 640x480@60Hz VGA timing parameters (pixel counts)
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

    -- Grid constants: spacing (in pixels) between gridlines
    -- GRID_H -> horizontal gridlines spaced every GRID_H rows
    -- GRID_V -> vertical gridlines spaced every GRID_V columns
    constant GRID_H : integer := 29;
    constant GRID_V : integer := 64;

    -- has_data: set once a capture has completed, so the waveform is only
    --           drawn after the BRAM actually contains a valid frame
    signal has_data        : STD_LOGIC := '0';
    -- pixel_threshold: BRAM sample scaled into a screen-row threshold,
    --                  used to decide which rows are "under" the trace
    signal pixel_threshold : integer range 0 to 479 := 0;

    -- Bitmap font geometry: each glyph is CHAR_W x CHAR_H pixels, drawn
    -- with CHAR_GAP pixels of spacing and scaled up by CHAR_SCALE
    constant CHAR_W      : integer := 5;
    constant CHAR_H      : integer := 7;
    constant CHAR_GAP    : integer := 1;
    constant CHAR_SCALE  : integer := 2;
    -- Top-left corner and length (in characters) of the time/division label
    constant LABEL_X0    : integer := 8;
    constant LABEL_Y0    : integer := 12;
    constant LABEL_LEN   : integer := 11;

    -- Kody znakow (indices into FONT_ROM identifying each glyph)
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

    -- One row of character codes making up a single label string
    type char_array_t is array (0 to LABEL_LEN - 1) of integer range 0 to 16;
    -- One label per decimation setting (0-5), selected by the "decimation" input
    type label_set_t is array (0 to 5) of char_array_t;

    -- Time/division label text for each of the 6 decimation settings,
    -- indexed the same way as capture_ctrl's decimation -> dec_max mapping
    -- (0 = x1 ... 5 = x32), spelling out "<value><unit>S/DIV"
    constant LABEL_SET : label_set_t := (
        0 => (CH_6, CH_4, CH_0, CH_U, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE, CH_SPACE),
        1 => (CH_1, CH_DOT, CH_2, CH_8, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE),
        2 => (CH_2, CH_DOT, CH_5, CH_6, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE),
        3 => (CH_5, CH_DOT, CH_1, CH_2, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V, CH_SPACE),
        4 => (CH_1, CH_0, CH_DOT, CH_2, CH_4, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V),
        5 => (CH_2, CH_0, CH_DOT, CH_4, CH_8, CH_M, CH_S, CH_SLASH, CH_D, CH_I, CH_V)
    );

    -- Font ROM: each entry is a flattened CHAR_H x CHAR_W (7x5) bitmap,
    -- read row-major (row*CHAR_W + col) to test individual pixels of a glyph
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

    -- Combinational result of the label-rendering process: '1' when the
    -- current pixel falls on a lit segment of the time/division label
    signal label_pixel : STD_LOGIC := '0';

begin

    -- Generates the 25 MHz pixel clock from the 100 MHz system clock
    CLK_WIZ : clk_wiz_0
        port map(
            clk_in1  => Clock100MHz,
            clk_out1 => clk25,
            reset    => reset,
            locked   => locked
        );

    -- Drives the BRAM read address from the horizontal counter so that
    -- each visible column reads the corresponding captured sample;
    -- holds at address 0 once past the visible region (h_cnt >= 640)
    bram_raddr <= STD_LOGIC_VECTOR(to_unsigned(h_cnt, 10))
                  when h_cnt < 640 else (others => '0');

    -- Data ready
    -- Latches has_data once a capture has finished, so the waveform is
    -- only drawn after the BRAM holds a complete, valid frame
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

    -- Converts the 12-bit BRAM sample for the current column into a
    -- 0-15 row-threshold value, used later to decide which screen rows
    -- lie "under" the waveform trace for that column
    process(clk25)
    begin
        if rising_edge(clk25) then
            pixel_threshold <= to_integer(unsigned(bram_rdata)) * 15 / 256;
        end if;
    end process;

    -- H and V counter
    -- Standard VGA raster counters: h_cnt sweeps 0..H_TOTAL-1 each line,
    -- v_cnt advances once per completed line and wraps at V_TOTAL-1
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
    --
    -- Combinationally determines whether the current (h_cnt, v_cnt)
    -- pixel falls inside the time/division label region and, if so,
    -- looks up the corresponding glyph in FONT_ROM and tests the
    -- individual font bit to decide whether the pixel is lit.
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
        -- Total on-screen size of the label, in pixels, given the font
        -- geometry and scale factor
        label_w := LABEL_LEN * (CHAR_W + CHAR_GAP) * CHAR_SCALE;
        label_h := CHAR_H * CHAR_SCALE;
        pix := '0';

        -- Select which label string to render based on the current
        -- decimation setting; clamp defensively to a valid index
        dec_idx := to_integer(unsigned(decimation));
        if dec_idx > 5 then
            dec_idx := 5;
        end if;
        current_label := LABEL_SET(dec_idx);

        -- Is the current pixel within the label's bounding box?
        inside_lbl := (h_cnt >= LABEL_X0) and (h_cnt < LABEL_X0 + label_w) and
                      (v_cnt >= LABEL_Y0) and (v_cnt < LABEL_Y0 + label_h);

        if inside_lbl then
            -- Pixel position relative to the label's top-left corner
            rel_x := h_cnt - LABEL_X0;
            rel_y := v_cnt - LABEL_Y0;

            -- Which character in the string, and which pixel within
            -- that (scaled) character cell, does this pixel fall on?
            char_idx  := rel_x / ((CHAR_W + CHAR_GAP) * CHAR_SCALE);
            col_in_ch := (rel_x mod ((CHAR_W + CHAR_GAP) * CHAR_SCALE)) / CHAR_SCALE;
            row_in_ch := rel_y / CHAR_SCALE;

            -- col_in_ch can land in the inter-character gap (>= CHAR_W);
            -- only sample FONT_ROM when within the actual glyph bitmap
            if char_idx < LABEL_LEN and col_in_ch < CHAR_W then
                bit_idx := row_in_ch * CHAR_W + col_in_ch;
                pix := FONT_ROM(current_label(char_idx))(bit_idx);
            end if;
        end if;

        label_pixel <= pix;
    end process;

    -- Ploting (data, grid, label)
    -- Combines, in priority order, the label overlay, the captured
    -- waveform trace, and the measurement grid into the final VGA RGB
    -- output for each active pixel; blanks the output outside the
    -- active drawing region
    process(clk25)
        variable on_grid_h : boolean;
        variable on_grid_v : boolean;
        variable on_signal : boolean;
    begin
        if rising_edge(clk25) then
            if active = '1' then
                -- Horizontal gridline: rows spaced every GRID_H pixels,
                -- measured up from the bottom of the visible area
                on_grid_h := ((V_VISIBLE - 1 - v_cnt) mod GRID_H) = 0;
                -- Vertical gridline: columns spaced every GRID_V pixels
                on_grid_v := (h_cnt mod GRID_V) = 0;
                -- Waveform trace: lit once data is available and the
                -- current row is at or below the sample's scaled height
                on_signal := has_data = '1' and
                             v_cnt >= (V_VISIBLE - pixel_threshold);

                -- Priority: label (green) > waveform (yellow) >
                -- grid (white) > background (black)
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
    -- Horizontal sync pulse: active-low for H_SYNC pixels, positioned
    -- after the visible area and front porch; held high (inactive)
    -- whenever the display is reset or disabled
    VGA_HS <= '0' when (reset = '0' and enable = '1') and
                       (h_cnt >= H_VISIBLE + H_FRONT) and
                       (h_cnt <  H_VISIBLE + H_FRONT + H_SYNC)
              else '1';

    -- Vertical sync pulse: same idea as VGA_HS, one line per frame
    VGA_VS <= '0' when (reset = '0' and enable = '1') and
                       (v_cnt >= V_VISIBLE + V_FRONT) and
                       (v_cnt <  V_VISIBLE + V_FRONT + V_SYNC)
              else '1';

    -- Active video region: visible columns/rows only, while running
    active <= '1' when (reset = '0' and enable = '1') and
                       (h_cnt < H_VISIBLE) and
                       (v_cnt < V_VISIBLE)
              else '0';

end Behavioral;
