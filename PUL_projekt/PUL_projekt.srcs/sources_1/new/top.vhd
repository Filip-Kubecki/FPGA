library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port(
        -- CLK and control
        Clock100MHz : in  STD_LOGIC;
        SW          : in  STD_LOGIC_VECTOR(3 downto 0);
        Button      : in  STD_LOGIC_VECTOR(3 downto 0);
        
        -- Encoder
        Encoder_A   : in  STD_LOGIC;
        Encoder_B   : in  STD_LOGIC;

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

    component debouncer is
        Port(
            Clock100MHz : in  STD_LOGIC;
            Button      : in  STD_LOGIC;
            send_pulse  : out STD_LOGIC
        );
    end component;

    component bram is
        Port(
            clk   : in  STD_LOGIC;
            we    : in  STD_LOGIC;
            waddr : in  STD_LOGIC_VECTOR(9 downto 0);
            wdata : in  STD_LOGIC_VECTOR(11 downto 0);
            raddr : in  STD_LOGIC_VECTOR(9 downto 0);
            rdata : out STD_LOGIC_VECTOR(11 downto 0)
        );
    end component;

    component capture_ctrl is
        Port(
            Clock100MHz  : in  STD_LOGIC;
            reset        : in  STD_LOGIC;
            trigger      : in  STD_LOGIC;
            trig_mode    : in  STD_LOGIC;
            trig_level   : in  STD_LOGIC_VECTOR(11 downto 0);
            decimation   : in  STD_LOGIC_VECTOR(2 downto 0);
            adc_data     : in  STD_LOGIC_VECTOR(11 downto 0);
            adc_valid    : in  STD_LOGIC;
            bram_we      : out STD_LOGIC;
            bram_waddr   : out STD_LOGIC_VECTOR(9 downto 0);
            bram_wdata   : out STD_LOGIC_VECTOR(11 downto 0);
            capture_done : out STD_LOGIC
        );
    end component;

    component vga_scope is
        Port(
            Clock100MHz  : in  STD_LOGIC;
            reset        : in  STD_LOGIC;
            enable       : in  STD_LOGIC;
            capture_done : in  STD_LOGIC;
            bram_raddr   : out STD_LOGIC_VECTOR(9 downto 0);
            bram_rdata   : in  STD_LOGIC_VECTOR(11 downto 0);
            decimation   : in  STD_LOGIC_VECTOR (2 downto 0);
            VGA_R        : out STD_LOGIC;
            VGA_G        : out STD_LOGIC;
            VGA_B        : out STD_LOGIC;
            VGA_HS       : out STD_LOGIC;
            VGA_VS       : out STD_LOGIC
        );
    end component;

    component encoder is
        Port(
            Clock100MHz : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            Encoder_A   : in  STD_LOGIC;
            Encoder_B   : in  STD_LOGIC;
            step_cw     : out STD_LOGIC;
            step_ccw    : out STD_LOGIC;
            position    : out signed(15 downto 0)
        );
    end component;

    -- Zmienne, stałe i sygnały

    signal bram_we      : STD_LOGIC := '0';
    signal bram_waddr   : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal bram_wdata   : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal bram_raddr   : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal bram_rdata   : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal capture_done : STD_LOGIC := '0';
    signal decimation   : unsigned(2 downto 0) := (others => '0');


    signal send_pulse : STD_LOGIC := '0';

    -- Encoder
    signal enc_cw   : STD_LOGIC := '0';
    signal enc_ccw  : STD_LOGIC := '0';
    signal enc_pos  : signed(15 downto 0) := (others => '0');

    signal reset      : STD_LOGIC;
    signal adc_en     : STD_LOGIC;
    signal vga_en     : STD_LOGIC;

    signal adc_data   : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal adc_valid  : STD_LOGIC := '0';

    -- Filter - Moving Average
    type avg_buf_t is array (0 to 7) of unsigned(11 downto 0);
    signal avg_buf    : avg_buf_t := (others => (others => '0'));
    signal avg_sum    : unsigned(14 downto 0) := (others => '0');
    signal avg_out    : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal avg_valid  : STD_LOGIC := '0';

    signal filtered_data  : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal filtered_valid : STD_LOGIC := '0';

    -- Stały próg triggera ~1V przy VREF=4.1V
    constant TRIG_LEVEL : STD_LOGIC_VECTOR(11 downto 0) := STD_LOGIC_VECTOR(to_unsigned(999, 12));

begin

    reset  <= SW(0); -- RESET
    vga_en <= SW(2); -- VGA ENABLE
    -- Przełącznik filtra
    filtered_data  <= avg_out   when SW(1) = '1' else adc_data;
    filtered_valid <= avg_valid  when SW(1) = '1' else adc_valid;
    -- SW(3) -- TRIGGER set 0 = przycisk, 1 = auto trigger

    -- Enkoder zmienia decimation (0-5)
    DEC_CTRL : process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                decimation <= (others => '0');
            else
                if enc_cw = '1' and decimation < 5 then
                    decimation <= decimation + 1;
                elsif enc_ccw = '1' and decimation > 0 then
                    decimation <= decimation - 1;
                end if;
            end if;
        end if;
    end process;

    -- Moving Average Filter N=8
    MA_FILTER : process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                avg_buf   <= (others => (others => '0'));
                avg_sum   <= (others => '0');
                avg_out   <= (others => '0');
                avg_valid <= '0';
            elsif adc_valid = '1' then
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

    -- Dekoduj pozycję na LED
LED <= "0000" when decimation = 0
       else "0001" when decimation = 1 
       else "0011" when decimation = 2 
       else "0111" when decimation = 3 
       else "1111";

    U_ADC : adc_reader
      port map(
          Clock100MHz => Clock100MHz,
          reset       => reset,
          enable      => '1',
          ADC_CLK     => ADC_CLK,
          ADC_CS      => ADC_CS,
          ADC_DOUT    => ADC_DOUT,
          data_out    => adc_data,
          data_valid  => adc_valid
      );

    U_BRAM : bram
      port map(
          clk   => Clock100MHz,
          we    => bram_we,
          waddr => bram_waddr,
          wdata => bram_wdata,
          raddr => bram_raddr,
          rdata => bram_rdata
      );

    U_CAP : capture_ctrl
        port map(
            Clock100MHz  => Clock100MHz,
            reset        => reset,
            trigger      => send_pulse,
            trig_mode    => SW(3),        -- 0=przycisk, 1=zbocze
            decimation   => STD_LOGIC_VECTOR(decimation),
            trig_level   => TRIG_LEVEL,
            adc_data     => filtered_data,
            adc_valid    => filtered_valid,
            bram_we      => bram_we,
            bram_waddr   => bram_waddr,
            bram_wdata   => bram_wdata,
            capture_done => capture_done
        );
        
    U_VGA : vga_scope
      port map(
          Clock100MHz  => Clock100MHz,
          reset        => reset,
          enable       => vga_en,
          capture_done => capture_done,
          bram_raddr   => bram_raddr,
          bram_rdata   => bram_rdata,
          decimation   => STD_LOGIC_VECTOR(decimation),
          VGA_R        => VGA_R,
          VGA_G        => VGA_G,
          VGA_B        => VGA_B,
          VGA_HS       => VGA_HS,
          VGA_VS       => VGA_VS
      );

    U_DEBOUNCER : debouncer
      port map(
          Clock100MHz => Clock100MHz,
          Button      => Button(0),
          send_pulse  => send_pulse
      );

    U_ENC : encoder
      port map(
          Clock100MHz => Clock100MHz,
          reset       => reset,
          Encoder_A   => Encoder_A,
          Encoder_B   => Encoder_B,
          step_cw     => enc_cw,
          step_ccw    => enc_ccw,
          position    => enc_pos
      );

end Behavioral;
