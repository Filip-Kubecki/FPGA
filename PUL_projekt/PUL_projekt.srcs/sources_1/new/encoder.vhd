library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity encoder is
    Port(
        Clock100MHz : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        Encoder_A   : in  STD_LOGIC;
        Encoder_B   : in  STD_LOGIC;
        step_cw     : out STD_LOGIC;
        step_ccw    : out STD_LOGIC;
        position    : out signed(15 downto 0)
    );
end encoder;

architecture Behavioral of encoder is

    type bt_state_t is (STABILNY, OPOZNIENIE, WCISNIETY);

    signal a_state      : bt_state_t := STABILNY;
    signal b_state      : bt_state_t := STABILNY;
    signal a_debounced  : STD_LOGIC := '0';
    signal b_debounced  : STD_LOGIC := '0';
    signal a_cnt        : unsigned(19 downto 0) := (others => '0');
    signal b_cnt        : unsigned(19 downto 0) := (others => '0');
    constant DEBOUNCE   : unsigned(19 downto 0) := to_unsigned(1000, 20);

    signal a_prev       : STD_LOGIC := '0';
    signal pos_reg      : signed(15 downto 0) := (others => '0');

begin

    position <= pos_reg;

    -- Debouncer A
    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                a_cnt       <= (others => '0');
                a_debounced <= '0';
                a_state     <= STABILNY;
            else
                case a_state is
                    when STABILNY =>
                        a_cnt <= (others => '0');
                        if Encoder_A /= a_debounced then
                            a_state <= OPOZNIENIE;
                        end if;
                    when OPOZNIENIE =>
                        a_cnt <= a_cnt + 1;
                        if Encoder_A = a_debounced then
                            a_state <= STABILNY;
                            a_cnt   <= (others => '0');
                        elsif a_cnt >= DEBOUNCE then
                            a_debounced <= Encoder_A;
                            a_state     <= WCISNIETY;
                            a_cnt       <= (others => '0');
                        end if;
                    when WCISNIETY =>
                        if Encoder_A = a_debounced then
                            a_state <= STABILNY;
                        end if;
                    when others =>
                        a_state <= STABILNY;
                end case;
            end if;
        end if;
    end process;

    -- Debouncer B
    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                b_cnt       <= (others => '0');
                b_debounced <= '0';
                b_state     <= STABILNY;
            else
                case b_state is
                    when STABILNY =>
                        b_cnt <= (others => '0');
                        if Encoder_B /= b_debounced then
                            b_state <= OPOZNIENIE;
                        end if;
                    when OPOZNIENIE =>
                        b_cnt <= b_cnt + 1;
                        if Encoder_B = b_debounced then
                            b_state <= STABILNY;
                            b_cnt   <= (others => '0');
                        elsif b_cnt >= DEBOUNCE then
                            b_debounced <= Encoder_B;
                            b_state     <= WCISNIETY;
                            b_cnt       <= (others => '0');
                        end if;
                    when WCISNIETY =>
                        if Encoder_B = b_debounced then
                            b_state <= STABILNY;
                        end if;
                    when others =>
                        b_state <= STABILNY;
                end case;
            end if;
        end if;
    end process;

    -- Dekoder kierunku na rosnącym zboczu A
    process(Clock100MHz)
    begin
        if rising_edge(Clock100MHz) then
            if reset = '1' then
                a_prev   <= '0';
                step_cw  <= '0';
                step_ccw <= '0';
                pos_reg  <= (others => '0');
            else
                a_prev   <= a_debounced;
                step_cw  <= '0';
                step_ccw <= '0';

                if a_debounced = '1' and a_prev = '0' then
                    if b_debounced = '0' then
                        step_cw <= '1';
                        pos_reg <= pos_reg + 1;
                    else
                        step_ccw <= '1';
                        pos_reg  <= pos_reg - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
