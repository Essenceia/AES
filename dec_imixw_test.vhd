--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   18:08:25 10/20/2021
-- Design Name:   
-- Module Name:   /home/ise/Documents/aes_decode/aes_inv_mixw_test.vhd
-- Project Name:  aes_decode
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: aes_inv_mixw
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY aes_inv_mixw_test IS
END aes_inv_mixw_test;
 
ARCHITECTURE behavior OF aes_inv_mixw_test IS 
 
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
		-- f0 85 57 68 10 93 ed 9c be 2c 97 4e
      w_i <= x"1924d1c7";	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
