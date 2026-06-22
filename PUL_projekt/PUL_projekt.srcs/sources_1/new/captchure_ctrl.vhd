library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity capture_ctrl is
    Port(
        Clock100MHz  : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        trigger      : in  STD_LOGIC;
        trig_mode    : in  STD_LOGIC;
        trig_level   : in  STD_LOGIC_VECTOR(11 downto 0);
        -- Decimation: 0=x1, 1=x2, 2=x4, 3=x8, 4=x16, 5=x32
        decimation   : in  unsigned(2 downto 0);
        -- ADC
        adc_data     : in  STD_LOGIC_VECTOR(11 downto 0);
        adc_valid    : in  STD_LOGIC;
        -- BRAM zapis 
        bram_we      : out STD_LOGIC;
        bram_waddr   : out STD_LOGIC_VECTOR(9 downto 0);
        bram_wdata   : out STD_LOGIC_VECTOR(11 downto 0);
        -- Status
        capture_done : out STD_LOGIC
    );
end capture_ctrl;

architecture Behavioral of capture_ctrl is

    type state_t is (IDLE, ARMED, CAPTURING, DONE);
    signal state    : state_t := IDLE;
    signal w_addr   : unsigned(9 downto 0) := (others => '0');
    signal adc_prev : unsigned(11 downto 0) := (others => '0');

    -- Licznik decimation
    signal dec_cnt  : unsigned(4 downto 0) := (others => '0');
    signal dec_max  : unsigned(4 downto 0) := (others => '0');

begin

    bram_wdata <= adc_data;
    bram_waddr <= STD_LOGIC_VECTOR(w_addr);

    process(decimation)
    begin
        case decimation is
            when "000"  => dec_max <= "00000";
            when "001"  => dec_max <= "00001";
            when "010"  => dec_max <= "00011";
            when "011"  => dec_max <= "00111";
            when "100"  => dec_max <= "01111";
            when "101"  => dec_max <= "11111";
            when others => dec_max <= "00000";
        end case;
    end process;

    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                state        <= IDLE;
                w_addr       <= (others => '0');
                bram_we      <= '0';
                capture_done <= '0';
                adc_prev     <= (others => '0');
                dec_cnt      <= (others => '0');
            else
                bram_we      <= '0';
                capture_done <= '0';

                if adc_valid = '1' then
                    adc_prev <= unsigned(adc_data);
                end if;

                case state is

                    when IDLE =>
                        w_addr  <= (others => '0');
                        dec_cnt <= (others => '0');
                        if trig_mode = '0' then
                            if trigger = '1' then
                                state <= CAPTURING;
                            end if;
                        else
                            if trigger = '1' then
                                state <= ARMED;
                            end if;
                        end if;

                    when ARMED =>
                        if trig_mode = '0' then
                            state <= IDLE;
                        elsif adc_valid = '1' then
                            if adc_prev < unsigned(trig_level) and
                               unsigned(adc_data) >= unsigned(trig_level) then
                                state   <= CAPTURING;
                                dec_cnt <= (others => '0');
                            end if;
                        end if;
                    when CAPTURING =>
                        if adc_valid = '1' then
                            if dec_cnt = dec_max then
                                -- Zapisz próbkę do BRAM
                                bram_we <= '1';
                                w_addr  <= w_addr + 1;
                                dec_cnt <= (others => '0');
                                if w_addr = 639 then
                                    state <= DONE;
                                end if;
                            else
                                dec_cnt <= dec_cnt + 1;
                            end if;
                        end if;

                    when DONE =>
                        capture_done <= '1';
                        if trig_mode = '0' then
                            if trigger = '1' then
                                state   <= CAPTURING;
                                w_addr  <= (others => '0');
                                dec_cnt <= (others => '0');
                            end if;
                        else
                            state   <= ARMED;
                            w_addr  <= (others => '0');
                            dec_cnt <= (others => '0');
                        end if;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
