	proc get_random_element(elements, probabilities,randValue){
		var elist : [1..elements.size] int;
		var count = 0;
		for each in elements{
			count += 1;
			elist[count] = each;
		}
		var temp_sum = 0.0: real;
		var the_index = -99;
		for i in probabilities.domain do
		{
			temp_sum += probabilities[i];
			if randValue <= temp_sum
			{
				the_index = i;
				break;
			}
		}
		return elist[1];
	}
