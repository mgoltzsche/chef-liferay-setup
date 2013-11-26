class Chef
  class Recipe
    def ldapSuffix(domain)
      domain.map{|dc| "dc=#{dc}"}.join(',')
    def ldapPassword(password)
      chars = ('a'..'z').to_a + ('0'..'9').to_a
      salt = Array.new(8, '').collect { chars[rand(chars.size)] }.join('')
      password = '{ssha}' + Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp!
      Base64.encode64(password).chomp!.sub("\n", "\n ")
    end
  end
end
