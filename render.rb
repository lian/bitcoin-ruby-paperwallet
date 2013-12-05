require "bundler/setup"
require 'ffi-cairo'
require 'rqrcode'
require 'bitcoin'

module Bitcoin
  module PaperWallet
    module Draw
      extend self

      def draw_addresses(addresses, wallet_name=nil, type=:bitcoin)
        addrs = addresses

        Bitcoin.network = type
        width, height = 2480, 3508 # DIN A4 at 300 dpi
        w, h = width/2, height/2 # half width, height

        filename_base = "qr-#{Bitcoin.network_name}-addr"
        count = 0
        files = []

        addrs.each_slice(2).to_a.each_slice(4).to_a.each.with_index{|out,page_index|
          surface = Cairo.cairo_image_surface_create(Cairo::CAIRO_FORMAT_ARGB32, width, height)
          cr = Cairo.cairo_create(surface)
          c = Cairo::ContextHelper.new(cr, surface)
          c.set_source_rgb(1, 1, 1); c.rectangle(0, 0, width, height); c.fill
          part_top_padding, part_bottom_padding = 130, 135
          current_height = 0

          out.each{|addr_left,addr_right|
            #p [part_index, addr, part]
            #p [part_index, addr_num, addr]
            item_start_height = current_height
            current_height += part_top_padding

            text = addr_left
            c.font = "Mono"; c.font_size = 45; c.set_source_rgb(0, 0, 0)
            text_extents = c.text_extents(text)
            current_height += text_extents[:height]
            c.move_to((w / 2) - (text_extents[:width]/2), current_height)
            c.show_text(text)
            current_height -= text_extents[:height]

            text = addr_right
            c.font = "Mono"; c.font_size = 45; c.set_source_rgb(0, 0, 0)
            text_extents = c.text_extents(text)
            current_height += text_extents[:height]
            c.move_to(w + (w / 2) - (text_extents[:width]/2), current_height)
            c.show_text(text)

            current_height += text_extents[:height] * 2.5 # just padding for the next element


            dot_size = 14
            qr = RQRCode::QRCode.new(addr_left, :size => 4, :level => :l)
            qr_length = qr.modules.size*dot_size
            start_x, start_y = ((w / 3)*2) - (qr_length/2), current_height

            qr.modules.each_index{|x|
              qr.modules.each_index{|y|
                color = qr.dark?(x,y) ? [0, 0, 0] : [1,1,1]
                c.set_source_rgb(*color)
                c.rectangle(start_x+(y*dot_size), start_y+(x*dot_size), dot_size, dot_size)
                c.fill
              }
            }

            qr = RQRCode::QRCode.new(addr_right, :size => 4, :level => :l)
            qr_length = qr.modules.size*dot_size
            start_x, start_y = w + ((w / 3)*2) - (qr_length/2), current_height

            qr.modules.each_index{|x|
              qr.modules.each_index{|y|
                color = qr.dark?(x,y) ? [0, 0, 0] : [1,1,1]
                c.set_source_rgb(*color)
                c.rectangle(start_x+(y*dot_size), start_y+(x*dot_size), dot_size, dot_size)
                c.fill
              }
            }

            padding = 80
            c.font = "Mono"; c.font_size = 25; c.set_source_rgb(0, 0, 0)

            side_text = [
              "network: #{Bitcoin.network_name}",
              "address: #{count += 1}",
              "balance:",
            ]
            side_text.unshift("wallet: #{wallet_name}") if wallet_name

            text_extents = c.text_extents("A")
            line_height = text_extents[:height] * 1.4
            base_height = (current_height + (qr_length/2)) - ((line_height*side_text.size) / 2)

            side_text.each.with_index{|text,index|
              c.move_to(padding, base_height + (line_height*index))
              c.show_text(text)
            }


            side_text = [
              "network: #{Bitcoin.network_name}",
              "address: #{count += 1}",
              "balance:",
            ]
            side_text.unshift("wallet: #{wallet_name}") if wallet_name

            text_extents = c.text_extents("A")
            line_height = text_extents[:height] * 1.4
            base_height = (current_height + (qr_length/2)) - ((line_height*side_text.size) / 2)

            side_text.each.with_index{|text,index|
              c.move_to(w + padding, base_height + (line_height*index))
              c.show_text(text)
            }


            current_height += qr_length
            current_height += part_bottom_padding
            c.set_source_rgb(0, 0, 0); c.rectangle(0, current_height, width, 2); c.fill

            item_total_height = current_height-item_start_height
            c.set_source_rgb(0, 0, 0); c.rectangle(w, current_height-item_total_height+(item_total_height*0.1), 2, (item_total_height*0.8)); c.fill
          }

          filename = filename_base + "-page%d.png" % [page_index+1]
          c.to_png(filename)
          c.destroy
          files << filename
        }

        #system("feh", *files) if system("which feh")
        files
      end


      def draw_shares(all_shares, available, needed, wallet_name=nil, type=:bitcoin)
        Bitcoin.network = type
        #width, height = 1240, 1754 # DIN A4 at 150 dpi
        width, height = 2480, 3508 # DIN A4 at 300 dpi
        w, h = width/2, height/2 # half width, height

        filename_base = "qr-#{Bitcoin.network_name}-parts"
        files = []
        addr_num = 0
        part_cur = 0

        files += draw_addresses(all_shares.map{|i| i[0] }, wallet_name, type)

        available.times{|part_index|
          all_shares.each_slice(4).each.with_index{|out,page_index|

            surface = Cairo.cairo_image_surface_create(Cairo::CAIRO_FORMAT_ARGB32, width, height)
            cr = Cairo.cairo_create(surface)
            c = Cairo::ContextHelper.new(cr, surface)
            c.set_source_rgb(1, 1, 1); c.rectangle(0, 0, width, height); c.fill
            part_top_padding, part_bottom_padding = 110, 105
            current_height = 0

            out.each.with_index{|(addr,parts),addr_index| part = parts[part_index]
              if part_index != part_cur
                part_cur, addr_num = part_index, 0
              end
              addr_index = (addr_num += 1)

              #p [part_index, addr, part]
              p [part_index, addr_num, addr]

              item_start_height = current_height
              current_height += part_top_padding

              text = addr
              c.font = "Mono"; c.font_size = 45; c.set_source_rgb(0, 0, 0)
              text_extents = c.text_extents(text)
              current_height += text_extents[:height]
              c.move_to((w / 2) - (text_extents[:width]/2), current_height)
              c.show_text(text)
              current_height -= text_extents[:height]*1.5

              c.font = "Mono"; c.font_size = 35; c.set_source_rgb(0, 0, 0)
              text_extents = c.text_extents("A")
              line_height = text_extents[:height] * 1.4
              part.bytes.each_slice(40).map{|t|
                text = t.pack("C*")
                text_extents = c.text_extents(text)
                current_height += line_height
                c.move_to((w + (w / 2)) - (text_extents[:width]/2), current_height)
                c.show_text(text)
              }

              current_height += line_height * 2.5 # just padding for the next element


              dot_size = 14
              qr = RQRCode::QRCode.new(addr, :size => 5, :level => :l)
              qr_length = qr.modules.size*dot_size
              start_x, start_y = ((w / 3)*2) - (qr_length/2), current_height

              qr.modules.each_index{|x|
                qr.modules.each_index{|y|
                  color = qr.dark?(x,y) ? [0, 0, 0] : [1,1,1]
                  c.set_source_rgb(*color)
                  c.rectangle(start_x+(y*dot_size), start_y+(x*dot_size), dot_size, dot_size)
                  c.fill
                }
              }

              qr = RQRCode::QRCode.new(part, :size => 5, :level => :l)
              qr_length = qr.modules.size*dot_size
              start_x, start_y = w + ((w / 3)*2) - (qr_length/2), current_height

              qr.modules.each_index{|x|
                qr.modules.each_index{|y|
                  color = qr.dark?(x,y) ? [0, 0, 0] : [1,1,1]
                  c.set_source_rgb(*color)
                  c.rectangle(start_x+(y*dot_size), start_y+(x*dot_size), dot_size, dot_size)
                  c.fill
                }
              }


              padding = 80
              c.font = "Mono"; c.font_size = 25; c.set_source_rgb(0, 0, 0)

              side_text = [
                "network: #{Bitcoin.network_name}",
                "address: #{addr_index}",
                "available: #{available}",
                "needed: #{needed}",
                "part: #{part_index+1}",
              ]
              side_text.unshift("wallet: #{wallet_name}") if wallet_name

              text_extents = c.text_extents("A")
              line_height = text_extents[:height] * 1.4
              base_height = (current_height + (qr_length/2)) - ((line_height*side_text.size) / 2)

              side_text.each.with_index{|text,index|
                c.move_to(padding, base_height + (line_height*index))
                c.show_text(text)
                c.move_to(w + padding, base_height + (line_height*index))
                c.show_text(text)
              }

              current_height += qr_length
              current_height += part_bottom_padding
              c.set_source_rgb(0, 0, 0); c.rectangle(0, current_height, width, 2); c.fill

              item_total_height = current_height-item_start_height
              c.set_source_rgb(0, 0, 0); c.rectangle(w, current_height-item_total_height+(item_total_height*0.1), 2, (item_total_height*0.8)); c.fill
            }

            filename = filename_base + "-page%d-part%d.png" % [page_index+1, part_index+1]
            c.to_png(filename)
            c.destroy
            files << filename
          }
        }

        system("convert", *files, filename_base+".pdf") if system("which convert")
        #system("feh", *files) if system("which feh")
        system("rm", *files)
      end


      def draw_keys(keys, wallet_name=nil, type=:bitcoin)
        Bitcoin.network = type
        width, height = 2480, 3508 # DIN A4 at 300 dpi
        w, h = width/2, height/2

        filename_base, files = "qr-#{Bitcoin.network_name}-keys", []
        count = 0

        files += draw_addresses(keys.map{|i| i[0] }, wallet_name, type)

        keys.each_slice(4).each.with_index{|keys,part_index|

          surface = Cairo.cairo_image_surface_create(Cairo::CAIRO_FORMAT_ARGB32, width, height)
          cr = Cairo.cairo_create(surface)
          c = Cairo::ContextHelper.new(cr, surface)
          c.set_source_rgb(1, 1, 1); c.rectangle(0, 0, width, height); c.fill
          part_top_padding, part_bottom_padding = 130, 135
          current_height = 0

          keys.each.with_index{|(addr,priv),addr_index|  addr_index = count+=1
            p [:draw, addr, addr_index]
            raise "invalid address key pair #{addr} #{priv}" if !Bitcoin.valid_address?(addr) || Bitcoin::Key.from_base58(priv).addr != addr

            item_start_height = current_height
            current_height += part_top_padding

            text = addr
            c.font = "Mono"; c.font_size = 45; c.set_source_rgb(0, 0, 0)
            text_extents = c.text_extents(text)
            current_height += text_extents[:height]
            c.move_to((w / 2) - (text_extents[:width]/2), current_height)
            c.show_text(text)
            current_height -= text_extents[:height]
            #current_height += text_extents[:height] * 2 # just padding for the next element

            text = priv
            c.font = "Mono"; c.font_size = 35; c.set_source_rgb(0, 0, 0)
            text_extents = c.text_extents(text)
            current_height += text_extents[:height] + 5
            c.move_to((w + (w / 2)) - (text_extents[:width]/2), current_height)
            c.show_text(text)

            current_height += text_extents[:height] * 3 # just padding for the next element
            current_height += 11


            dot_size = 14
            qr = RQRCode::QRCode.new(addr, :size => 4, :level => :l)
            qr_length = qr.modules.size*dot_size
            start_x, start_y = ((w / 3)*2) - (qr_length/2), current_height

            qr.modules.each_index{|x|
              qr.modules.each_index{|y|
                color = qr.dark?(x,y) ? [0, 0, 0] : [1,1,1]
                c.set_source_rgb(*color)
                c.rectangle(start_x+(y*dot_size), start_y+(x*dot_size), dot_size, dot_size)
                c.fill
              }
            }

            qr = RQRCode::QRCode.new(priv, :size => 4, :level => :l)
            qr_length = qr.modules.size*dot_size
            start_x, start_y = w + ((w / 3)*2) - (qr_length/2), current_height

            qr.modules.each_index{|x|
              qr.modules.each_index{|y|
                color = qr.dark?(x,y) ? [0, 0, 0] : [1,1,1]
                c.set_source_rgb(*color)
                c.rectangle(start_x+(y*dot_size), start_y+(x*dot_size), dot_size, dot_size)
                c.fill
              }
            }


            padding = 80
            c.font = "Mono"; c.font_size = 25; c.set_source_rgb(0, 0, 0)

            side_text = [
              "network: #{Bitcoin.network_name}",
              "address: #{addr_index}",
            ]
            side_text.unshift("wallet: #{wallet_name}") if wallet_name

            text_extents = c.text_extents("A")
            line_height = text_extents[:height] * 1.4
            base_height = (current_height + (qr_length/2)) - ((line_height*side_text.size) / 2)

            side_text.each.with_index{|text,index|
              c.move_to(padding, base_height + (line_height*index))
              c.show_text(text)
            }


            side_text = [
              "network: #{Bitcoin.network_name}",
              "key: #{addr_index}",
            ]
            side_text.unshift("wallet: #{wallet_name}") if wallet_name

            text_extents = c.text_extents("A")
            line_height = text_extents[:height] * 1.4
            base_height = (current_height + (qr_length/2)) - ((line_height*side_text.size) / 2)

            side_text.each.with_index{|text,index|
              c.move_to(w + padding, base_height + (line_height*index))
              c.show_text(text)
            }


            current_height += qr_length
            current_height += part_bottom_padding
            #c.set_source_rgb(0, 0, 0); c.rectangle(width*0.1, current_height, width*0.8, 2); c.fill
            c.set_source_rgb(0, 0, 0); c.rectangle(0, current_height, width, 2); c.fill

            item_total_height = current_height-item_start_height
            c.set_source_rgb(0, 0, 0); c.rectangle(w, current_height-item_total_height+(item_total_height*0.1), 2, (item_total_height*0.8)); c.fill
          }

          # finish page
          filename = filename_base + "-%d.png" % part_index
          c.to_png(filename)
          c.destroy
          files << filename
        }

        system("convert", *files, filename_base+".pdf") if system("which convert")
        #system("feh", *files) if system("which feh")
        system("rm", *files)
      end

    end
  end
end
