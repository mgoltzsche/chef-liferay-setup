class Chef
  class Recipe
    def ldapSuffix(domain)
      domain.split('.').map{|dc| "dc=#{dc}"}.join(',')
    end
    def ldapPassword(password)
      chars = ('a'..'z').to_a + ('0'..'9').to_a
      salt = Array.new(8, '').collect { chars[rand(chars.size)] }.join('')
      password = '{ssha256}' + Base64.encode64(Digest::SHA256.digest(password+salt)+salt).chomp!
      Base64.encode64(password).chomp!.gsub!("\n", "\n ")
    end
  end
end
