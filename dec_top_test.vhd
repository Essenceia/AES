LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;

ENTITY ase_decode_top_test IS
END ase_decode_top_test;
 
ARCHITECTURE behavior OF ase_decode_top_test IS 
 
	COMPONENT ase_dec_top
	PORT(
		clk    : IN std_logic;
		nreset : IN std_logic;
		
		res_v_o : OUT std_logic;
		res_o   : OUT std_logic_vector(127 downto 0);
		data_v_i: IN  std_logic;
		data_i  : IN  std_logic_vector(127 downto 0);
		key_i   : IN  std_logic_vector(127 downto 0)
	);
	END COMPONENT;
    

	--Inputs
	signal nreset : std_logic := '0';
	signal data_v_i : std_logic := '0' ;
	signal data_i : std_logic_vector(127 downto 0) := (others => '0');
	signal key_i  : std_logic_vector(127 downto 0) := (others => '0'); -- x"5468617473206D79204B756E67204675";

 	--Outputs
	signal res_o : std_logic_vector(127 downto 0);
	signal res_v_o : std_logic;
	
	-- test signals
	signal clk  : std_logic := '0';

	-- clk 
	constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
	uut: ase_dec_top 
	PORT MAP (
		clk    => clk,
		nreset => nreset,
		
		res_v_o  => res_v_o,
		res_o    => res_o,
		data_v_i => data_v_i,
		data_i   => data_i,
		key_i    => key_i
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
		-- hold reset state for 100 ns.
		nreset <= '0';
		wait for clk_period;
		nreset <= '1';
		wait for clk_period;
		
		-- insert stimulus here 
		-- data_i   <= x"0336763e966d92595a567cc9ce537f5e" after clk_period; 
		-- x"54776F204F6E65204E696E652054776F" after clk_period;
		
		-- [ l : h ] x" 69 c4 e0 d8 6a 7b 04 30 d8 cd b7 80 70 b4 c5 5a";
		-- [ l : h ] c7 d1 24 19 48 9e 3b 62 33 a2 c5 a7 f4 56 31 72 
		data_i <= x"723156f4a7c5a233623b9e481924d1c7";
		-- [ l : h ]  x"13 11 1d 7f e3 94 4a 17 f3 07 a7 8b 4d 2b 30 c5";
		-- [ l : h ] b4ef5bcb3e92e21123e951cf6f8f188e 11
		key_i <= x"8e188f6fcf51e92311e2923ecb5befb4";
		-- key_i  <= x"c5302b4d8ba707f3174a94e37f1d1113";
		data_v_i <= '1';
		wait for 10 ns;
		data_v_i <= '0';
		
		wait;
	end process;

END;
