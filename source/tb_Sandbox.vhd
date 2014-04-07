LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY tb_Sandbox IS
END tb_Sandbox;
 
ARCHITECTURE behavior OF tb_Sandbox IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Sandbox
    PORT(
         clk : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Sandbox PORT MAP (
          clk => clk
        );

   -- Clock process definitions
   clk <= not clk after clk_period/2;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
