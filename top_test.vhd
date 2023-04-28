LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_misc.ALL;
use std.textio.all;
use ieee.std_logic_textio.all; 

ENTITY aes_enc_top_test IS
END aes_enc_top_test;
 
ARCHITECTURE behavior OF aes_enc_top_test IS 
 
	COMPONENT aes
	PORT(
		clk    : IN std_logic;
		nreset : IN std_logic;
			
		data_v_i : IN  std_logic;
         	data_i   : IN  std_logic_vector(127 downto 0);
		key_i    : IN  std_logic_vector(127 downto 0);
		
		res_v_o  : OUT std_logic;
        	res_o    : OUT std_logic_vector(127 downto 0)
        );
	END COMPONENT;
    

	--Inputs
	signal data_v_i : std_logic := '0' ;
   	signal data_i   : std_logic_vector(127 downto 0) := (others => '0');
	signal key_i    : std_logic_vector(127 downto 0) := x"5468617473206D79204B756E67204675";

 	--Outputs
	signal res_v_o : std_logic;
	signal res_o   : std_logic_vector(127 downto 0);
	
	-- clock and reset
	signal clk    : std_logic := '0';
	signal nreset : std_logic := '0';

	-- debug and test bench singals
	signal tb_res_o_ored : std_logic;
	signal tb_data_i_ored : std_logic;
	signal tb_key_i_ored  : std_logic;
	file tb_data_i_file : text;
        file tb_key_i_file  : text;
        file tb_res_o_file  : text;

	constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
	uut: aes
	PORT MAP (
		clk    => clk,
		nreset => nreset,
		
		data_v_i => data_v_i,
		data_i   => data_i,
		key_i    => key_i,
		res_v_o  => res_v_o,
		res_o    => res_o
	);

	-- Clock process definitions
	clk_process :process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;

	-- test bench specific
   	tb_res_o_ored  <= or_reduce(res_o);
   	tb_data_i_ored <= or_reduce(data_i);
	tb_key_i_ored  <= or_reduce(key_i);

	-- assert process
	assert_proc : process
	begin
		wait for clk_period;
		-- TestBench verification 
		
		-- reset X check
		assert not(nreset='X') report "nreset is X" severity failure;
		-- input valid and data X check
		assert ( not( (data_v_i = 'X') and (nreset='1') )) 
		report "input valid is X" severity failure;

		assert ( not((data_v_i = '1')and (tb_data_i_ored='X') and (tb_key_i_ored='X') and (nreset='1') ))
		report "input data and key contrains X on valid" severity failure;
	
		-- Design verification
	
		-- output valid signal should never be X, with the expection of reset
	   	assert( not((res_v_o = 'X' )and (nreset = '1')) ) 
		report "output valid is X" severity failure;
		-- output data should never contrain and X's when output valid is 1
		-- with the expection of reset
		assert ( not((res_v_o = '1')and (tb_res_o_ored='X') and (nreset='1') ))
		report "output data contrains X on valid" severity failure;
	end process;

	-- test vector checking : check if output is the same as with openssl aes128 
	tv_proc : process
	variable tb_data_i_line : line;
	variable tb_key_i_line  : line;
	variable tb_res_o_line  : line;
	variable tb_data_i_line_vec : std_logic_vector(127 downto 0);
	variable tb_key_i_line_vec  : std_logic_vector(127 downto 0);
	variable tb_res_o_line_vec  : std_logic_vector(127 downto 0);
	
	begin
		-- file location is relative
		-- open files containing test vectors, different files for input/output
		file_open( tb_data_i_file, "tv/aes_enc_data_i.txt", read_mode);
		file_open( tb_key_i_file,  "tv/aes_enc_key_i.txt",  read_mode);
		file_open( tb_res_o_file,  "tv/aes_enc_res_o.txt", read_mode);
		nreset <= '0';
		wait for 16 ns;
		nreset  <= '1';
		-- tb_data_i and tb_res_o files have the same number of lines
		while not endfile( tb_data_i_file ) loop
			-- real file content line by line into a vector
			readline( tb_data_i_file, tb_data_i_line);
			readline( tb_key_i_file, tb_key_i_line);
			readline( tb_res_o_file, tb_res_o_line);
			read(tb_data_i_line, tb_data_i_line_vec);
			read(tb_key_i_line, tb_key_i_line_vec);
			read(tb_res_o_line, tb_res_o_line_vec);
				
			-- write to input
			data_v_i <= '1';		
			data_i <= tb_data_i_line_vec;
			key_i  <= tb_key_i_line_vec;
			
			wait for clk_period;
			
			data_v_i <= '0';
			data_i  <= ( others => 'X' );
			-- wait for module to produce valid output
			while not ( res_v_o = '1' ) loop
				wait for clk_period;
			end loop;
			-- test if module output matches test vector expected output
			assert( (res_v_o = '1') and ( res_o = tb_res_o_line_vec) ) 
			report "AES encoded output does not match test vector" severity failure;
			
			wait for clk_period;
		end loop;
		-- close files
		file_close( tb_data_i_file);
		file_close( tb_key_i_file);
		file_close( tb_res_o_file);
		wait;
end process;	
END;
