library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer is
    Port(
        Clock100MHz : in  STD_LOGIC;
        Button      : in  STD_LOGIC;
        send_pulse  : out STD_LOGIC
    );
end debouncer;

architecture Behavioral of debouncer is

    type bt_state_t is (STABILNY, OPOZNIENIE, WCISNIETY);
    signal bt_state   : bt_state_t := STABILNY;
    signal db_counter : unsigned(20 downto 0) := (others => '0');

    constant DEBOUNCE_TIME : unsigned(20 downto 0) := to_unsigned(2_000_000, 21);

begin

    process(Clock100MHz)
        variable trigger : STD_LOGIC;
    begin
        if rising_edge(Clock100MHz) then
            trigger    := Button;
            send_pulse <= '0';

            case bt_state is
                when STABILNY =>
                    db_counter <= (others => '0');
                    if trigger = '1' then
                        bt_state <= OPOZNIENIE;
                    end if;

                when OPOZNIENIE =>
                    db_counter <= db_counter + 1;
                    if trigger = '0' then
                        bt_state   <= STABILNY;
                        db_counter <= (others => '0');
                    elsif db_counter >= DEBOUNCE_TIME then
                        bt_state   <= WCISNIETY;
                        send_pulse <= '1';
                        db_counter <= (others => '0');
                    end if;

                when WCISNIETY =>
                    if trigger = '0' then
                        bt_state <= STABILNY;
                    end if;

                when others =>
                    bt_state <= STABILNY;
            end case;
        end if;
    end process;

end Behavioral;
