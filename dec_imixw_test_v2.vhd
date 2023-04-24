LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY inv_mixw_test IS
END inv_mixw_test;
 
ARCHITECTURE behavior OF inv_mixw_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT aes_inv_mixw
    PORT(
         w_i : IN  std_logic_vector(31 downto 0);
         mixw_o : OUT  std_logic_vector(31 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal w_i : std_logic_vector(31 downto 0) := (others => '0');

 	--Outputs
   signal mixw_o : std_logic_vector(31 downto 0);
   -- No clocks detected in port list. Replace clk below with 
   -- appropriate port name 
	signal clk : std_logic;
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: aes_inv_mixw PORT MAP (
          w_i => w_i,
          mixw_o => mixw_o
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
      wait for 10 ns;	
		w_i <= x"046681E5";
      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
