require "bundler/setup"
require "bitcoin"
require "shamir-secret-sharing"
require 'pp'

require_relative "render.rb"

module Bitcoin
  module PaperWallet
    extend self

    def generate(num=1, type=:bitcoin)
      Bitcoin.network = type
      keys = []
      num.times{|n|
        k = Bitcoin::Key.generate
        addr, priv = k.addr, k.to_base58
        if Bitcoin.valid_address?(addr) && Bitcoin::Key.from_base58(priv).addr == addr && Bitcoin::Key.from_base58(priv).to_base58 == priv
          keys << [addr, priv]
        end
        sleep 1
      }
      keys
    end

    def generate_parts(num=1, type=:bitcoin, available=4, needed=2)
      keys = num.is_a?(Numeric) ? generate(num, type) : num
      all_shares = keys.map{|addr,priv|
        shares = ShamirSecretSharing::Base58.split_with_sanity_check(priv, available, needed)
        [addr, shares]
      }
    end

    def combine_parts(addr, parts, type=:bitcoin)
      priv = ShamirSecretSharing::Base58.combine(parts, do_raise=true, data_checksum=true)
      Bitcoin::Key.from_base58(priv).addr == addr ? [addr, priv] : nil
    end

  end
end


network_type = :bitcoin
num_keys = 4

keys = Bitcoin::PaperWallet.generate(num_keys, network_type)
Bitcoin::PaperWallet::Draw.draw_keys(keys, network_type)

available, needed = 3, 2
#shares = Bitcoin::ColdStorage.generate_parts(num_keys, network_type, 3, 2)
shares = Bitcoin::PaperWallet.generate_parts(keys, network_type, available, needed)
Bitcoin::PaperWallet::Draw.draw_shares(shares, network_type)
