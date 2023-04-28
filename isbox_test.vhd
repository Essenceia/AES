LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
 
ENTITY inv_sbox_test IS
END inv_sbox_test;
 
ARCHITECTURE behavior OF inv_sbox_test IS 
 
	-- Component Declaration for the Unit Under Test (UUT)
	COMPONENT aes_inv_sbox
	PORT(
		data_i : IN  std_logic_vector(7 downto 0);
		data_o : OUT  std_logic_vector(7 downto 0)
	);
	END COMPONENT;
	    
	
	--Inputs
	signal data_i : std_logic_vector(7 downto 0) := (others => '0');
	
	--Outputs
	signal data_o : std_logic_vector(7 downto 0);
	-- No clocks detected in port list. Replace clk below with 
	-- appropriate port name 
	signal i : integer;
	signal clk : std_logic;
	constant clk_period : time := 10 ns;

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut: aes_inv_sbox PORT MAP (
		data_i => data_i,
		data_o => data_o
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
		for i in 0 to 256 loop
			data_i <= std_logic_vector(to_unsigned(i,8)); 
			wait for 10 ns;
		end loop;
		
		wait for clk_period*10;
		wait;
	end process;

END;
