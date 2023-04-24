--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:45:59 10/20/2021
-- Design Name:   
-- Module Name:   /home/ise/Documents/aes_decode/inv_sbox_test.vhd
-- Project Name:  aes_decode
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: aes_inv_sbox
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
use ieee.numeric_std.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
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

      -- insert stimulus here 

      wait;
   end process;

END;
