class Chef
	class Recipe
		def ldapSuffix(domain)
			domain.split('.').map{|dc| "dc=#{dc}"}.join(',')
		end
		def ldapPassword(password)
			chars = ('a'..'z').to_a + ('0'..'9').to_a
			salt = Array.new(8, '').collect { chars[rand(chars.size)] }.join('')
			ssha512Password = Base64.encode64(Digest::SHA512.digest(password+salt)+salt).gsub!("\n", '')
			Base64.encode64("{ssha512}#{ssha512Password}").gsub!("\n", '')
		end
	end
end
