LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
 
ENTITY aes_key_schedualing_test IS
END aes_key_schedualing_test;
 
ARCHITECTURE behavior OF aes_key_schedualing_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT ks
    PORT(
         key_i : IN  std_logic_vector(127 downto 0);
         key_rcon_i : IN  std_logic_vector(7 downto 0);
         key_next_o : OUT  std_logic_vector(127 downto 0);
         key_rcon_o : OUT  std_logic_vector(7 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal key_i : std_logic_vector(127 downto 0) := (others => '0');
   signal key_rcon_i : std_logic_vector(7 downto 0) := (others => '0');
   signal key_rcon_o : std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal key_next_o : std_logic_vector(127 downto 0);
   -- No clocks detected in port list. Replace clk below with 
   -- appropriate port name 
   signal clk : std_logic;
   signal key_rcon_next : std_logic_vector(7 downto 0);
   signal key_next      : std_logic_vector(127 downto 0);
   constant clk_period : time := 10 ns;

   -- rcon
   -- i    	1	2	3	4	5	6	7	8	9	10
   -- rcon     01      02	04	08	10	20	40	80	1B	36
   type rcon_array is array (0 to 9) of std_logic_vector(7 downto 0); 
   signal tb_rcon : rcon_array := ( x"01",x"02",x"04",x"08",x"10",x"20",x"40",x"80",x"1B",x"36");
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: ks PORT MAP (
          key_i => key_i,
          key_rcon_i => key_rcon_i,
          key_next_o => key_next_o,
          key_rcon_o => key_rcon_o
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      wait for clk_period / 2;	
		key_rcon_i <= "00000001";
		key_i    <= x"2b7e151628aed2a6abf7158809cf4f3c";
		wait for clk_period;
		for i in 0 to 15 loop
				key_rcon_next <= key_rcon_o;				
				key_next      <= key_next_o;				
				wait for clk_period;
				key_rcon_i <= key_rcon_next;
				key_i      <= key_next;
		 end loop;
      wait;
   end process;

END;
