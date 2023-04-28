LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all; 

 
ENTITY aes_mix_columns_test IS
END aes_mix_columns_test;
 
ARCHITECTURE behavior OF aes_mix_columns_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT aes_mixw
    PORT(
         w_i    : IN   std_logic_vector(31 downto 0);
         mixw_o : OUT  std_logic_vector(31 downto 0)
        );
    END COMPONENT;
    

   -- test bench signals
	constant clk_period : time := 10 ns;
	
	signal clk : std_logic := '0';
	signal test_diff : std_logic_vector(31 downto 0);
	type test_vector is array(3 downto 0) of std_logic_vector(31 downto 0);
	signal test_input  : test_vector := ( x"1a96de77",x"e598271e",x"3b87db49",x"305dbfd4");
	signal test_output : test_vector := ( x"e5b06b1b",x"4c260628",x"f1ca4d58",x"e5816604");
	
	signal data_i : std_logic_vector(31 downto 0) := (others => 'X');
	signal data_o : std_logic_vector(31 downto 0);
	

BEGIN
 
   -- Instantiate the Unit Under Test (UUT)
   uut: aes_mixw PORT MAP (
          w_i    => data_i,
          mixw_o => data_o
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
      wait for 10 ns;

		-- test all the inputs to an foward sbox and compare the outputs
		 for i in 0 to 3 loop
				data_i <= test_input(i);
				-- test resturn data_o against sbox values 
				wait for clk_period/10;
				test_diff <= data_o xor test_output(i);	
				wait for clk_period/10;
	
				assert  ( data_o = test_output(i) )
				report " Output doesn't match expected " severity failure;
				
				wait for clk_period;
		 end loop;
      wait;
   end process;
END;
