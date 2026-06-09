library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity capture_ctrl is
    Port(
        Clock100MHz : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        -- Trigger od debouncera
        trigger     : in  STD_LOGIC;
        -- ADC
        adc_data    : in  STD_LOGIC_VECTOR(11 downto 0);
        adc_valid   : in  STD_LOGIC;
        -- BRAM zapis
        bram_we     : out STD_LOGIC;
        bram_waddr  : out STD_LOGIC_VECTOR(9 downto 0);
        bram_wdata  : out STD_LOGIC_VECTOR(11 downto 0);
        -- Status
        capture_done : out STD_LOGIC  -- '1' gdy BRAM pełny
    );
end capture_ctrl;

architecture Behavioral of capture_ctrl is

    type state_t is (IDLE, CAPTURING, DONE);
    signal state    : state_t := IDLE;
    signal w_addr   : unsigned(9 downto 0) := (others => '0');

begin

    bram_wdata <= adc_data;
    bram_waddr <= STD_LOGIC_VECTOR(w_addr);

    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                state        <= IDLE;
                w_addr       <= (others => '0');
                bram_we      <= '0';
                capture_done <= '0';

            else
                bram_we      <= '0';
                capture_done <= '0';

                case state is

                    when IDLE =>
                        w_addr <= (others => '0');
                        if trigger = '1' then
                            state <= CAPTURING;
                        end if;

                    when CAPTURING =>
                        if adc_valid = '1' then
                            bram_we <= '1';
                            w_addr  <= w_addr + 1;
                            if w_addr = 639 then
                                state <= DONE;
                            end if;
                        end if;

                    when DONE =>
                        capture_done <= '1';
                        -- Czekaj na kolejny trigger
                        if trigger = '1' then
                            state  <= CAPTURING;
                            w_addr <= (others => '0');
                        end if;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
