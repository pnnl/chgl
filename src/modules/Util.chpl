module Util {

  	use Math;

	proc factorial(x: int) : int
	{
  	  if x < 0 then
    	    halt("factorial -- Sorry, this is not the gamma procedure!");

  	  return if x == 0 then 1 else x * factorial(x-1);
	}

	proc combinations(n: int, m: int): int
	{
	  return factorial(n)/(factorial(n-m)*factorial(m));
	}
}
