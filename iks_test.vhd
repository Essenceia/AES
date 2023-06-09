LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY aes_inv_key_schedualing_test IS
END aes_inv_key_schedualing_test;
 
ARCHITECTURE behavior OF aes_inv_key_schedualing_test IS 
	
	 -- Component Declaration for the Unit Under Test (UUT)
	
	 COMPONENT iks
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
	-- test bench signals
	-- b1d4d8e2 8a7db9da 1d7bb3de 4c664941
	-- 
	signal tb_rnd_1 : std_logic_vector(127 downto 0) := x"b1d4d8e28a7db9da1d7bb3de4c664941";
	constant clk_period : time := 10 ns;
	
	-- rcon
	type rcon_array is array (0 to 9) of std_logic_vector(7 downto 0); 
	signal tb_rcon : rcon_array := ( x"01",x"02",x"04",x"08",x"10",x"20",x"40",x"80",x"1B",x"36");
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
	uut: iks PORT MAP (
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
	  	key_rcon_i <= x"36";
		-- 014f9a8 c9ee2589 e13f0cc8 b6630ca6
		key_i <= x"8e188f6fcf51e92311e2923ecb5befb4";
	  	wait for clk_period;
	  	for i in 0 to 50 loop
	  			key_rcon_next <= key_rcon_o;				
	  			key_next      <= key_next_o;				
	  			wait for clk_period;
	  			key_rcon_i <= key_rcon_next;
	  			key_i      <= key_next;
	  	 end loop;
	wait;
	end process;

END;
