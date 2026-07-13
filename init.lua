-- loss probabilities array (one in X will be lost)
local loss_prob = {}

loss_prob["default:cobble"] = 3
loss_prob["default:dirt"] = 4

local radius_max = tonumber(core.settings:get("tnt_radius_max") or 25)

local eject_drops = function(pos, stack)
  local obj = core.add_item(pos, stack)

  if obj == nil then
    return
  end
  obj:get_luaentity().collect = true
  obj:set_acceleration({x=0, y=-10, z=0})
  obj:set_velocity({x=math.random(0,6)-3, y=10, z=math.random(0,6)-3})
end

local add_drop = function(drops, pos, item)
  if loss_prob[item] ~= nil then
    if math.random(1,loss_prob[item]) == 1 then
      return
    end
  end

  if drops[item] == nil then
    drops[item] = ItemStack(item)
  else
    drops[item]:add_item(item)
  end

  if drops[item]:get_free_space() == 0 then
    local stack = drops[item]
    eject_drops(pos, stack)
    drops[item] = nil
  end
end
--THIS IS WHERE ALL THE DESTROY CODE IS
local destroy = function(nodename, drops, pos, last, fast)
  if core.is_protected(pos, "") then
    return
  end

  -- local nodename = core.get_node(pos).name

  local def = core.registered_nodes[nodename]
  if def and def.groups.immortal then
    return
  end
  if nodename ~= "air" then
    core.remove_node(pos)
    if last then
      core.check_for_falling(pos)
    end
    if def and def.groups.flammable then
      core.set_node(pos, {name="fire:basic_flame"})
      return
    end
    local drop = core.get_node_drops(nodename, "")
    for _,item in ipairs(drop) do
      if type(item) == "string" then
        add_drop(drops, pos, item)
      else
        for i=1,item:get_count() do
          add_drop(drops, pos, item:get_name())
        end
      end
    end
  end
end

boom = function(pos, time)
  core.after(time, function(pos)
    if core.get_node(pos).name ~= "jc_tnt:tnt_burning" then
      return
    end
    core.sound_play("tnt_explode", {pos=pos, gain=1.5, max_hear_distance=2*64})
    core.set_node(pos, {name="jc_tnt:boom"})
    core.after(0.5, function(pos)
      core.remove_node(pos)
    end, {x=pos.x, y=pos.y, z=pos.z})


    local radius = 2
    local drops = {}
    local list = {}
    local dr = 0
    local tnts = 1
    local destroyed = 0
    while dr<radius do
      dr=dr+1
      for dx=-dr,dr,dr*2 do
        for dy=-dr,dr,1 do
          for dz=-dr,dr,1 do
            table.insert(list, {x=dx, y=dy, z=dz})
          end
        end
      end
      for dy=-dr,dr,dr*2 do
        for dx=-dr+1,dr-1,1 do
          for dz=-dr,dr,1 do
            table.insert(list, {x=dx, y=dy, z=dz})
          end
        end
      end
      for dz=-dr,dr,dr*2 do
        for dx=-dr+1,dr-1,1 do
          for dy=-dr+1,dr-1,1 do
            table.insert(list, {x=dx, y=dy, z=dz})
          end
        end
      end
        for _,p in ipairs(list) do
          local np = {x=pos.x+p.x, y=pos.y+p.y, z=pos.z+p.z}

          local node = core.get_node(np)
          local nodename = node.name
          if nodename == "air" then
          elseif nodename == "jc_tnt:tnt" or nodename == "jc_tnt:tnt_burning" then
            if radius < radius_max then
              if radius <= 5 then
                radius = radius + 1
              elseif radius <= 10 then
                radius = radius + 0.5
              else
                radius = radius + 0.3
              end
              core.remove_node(np)
            tnts = tnts + 1
            else
            core.set_node(np, {name="jc_tnt:tnt_burning"})
            boom(np, 1)
            end
          elseif nodename == "fire:basic_flame"
            --or string.find(node.name, "default:water_")
            --or string.find(node.name, "default:lava_")
            or nodename == "jc_tnt:boom"
            then

          else
            if math.abs(p.x)<2 and math.abs(p.y)<2 and math.abs(p.z)<2 then
              destroy(nodename, drops, np, dr == radius, radius > 7)
              destroyed = destroyed + 1
            else
              if math.random(1,5) <= 4 then
                destroy(nodename, drops, np, dr == radius, radius > 7)
                destroyed = destroyed + 1
              end
            end
          end
        end
    end

    local objects = core.get_objects_inside_radius(pos, radius*2)
    for _,obj in ipairs(objects) do
      --if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().name ~= "__builtin:item") then
        local p = obj:get_pos()
        local v = obj:get_velocity()
        local vec = {x=p.x-pos.x, y=p.y-pos.y, z=p.z-pos.z}
        local dist = (vec.x^2+vec.y^2+vec.z^2)^0.5
        dist = math.max(dist, 0.1)
        local damage = ((radius*20)/dist)
        --print("DMG dist="..dist.." damage="..damage)
        if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().name ~= "__builtin:item") then
        obj:punch(obj, 1.0, {
          full_punch_interval=1.0,
          damage_groups={fleshy=damage},
        }, vec)
        end
        if v ~= nil then
          --obj:set_velocity({x=(p.x - pos.x) + (radius / 4) + v.x, y=(p.y - pos.y) + (radius / 2) + v.y, z=(p.z - pos.z) + (radius / 4) + v.z})
          obj:set_velocity({x=(p.x - pos.x) + (radius / 2) + v.x, y=(p.y - pos.y) + radius + v.y,       z=(p.z - pos.z) + (radius / 2) + v.z})
        end
      --end
    end


    print("TNT exploded=" .. tnts .. " radius=" .. radius .. " destroyed="..destroyed)

    for _,stack in pairs(drops) do
      eject_drops(pos, stack)
    end
    local radiusp = radius+1
    core.add_particlespawner(
      100, --amount
      0.1, --time
      {x=pos.x-radiusp, y=pos.y-radiusp, z=pos.z-radiusp}, --minpos
      {x=pos.x+radiusp, y=pos.y+radiusp, z=pos.z+radiusp}, --maxpos
      {x=-0, y=-0, z=-0}, --minvel
      {x=0, y=0, z=0}, --maxvel
      {x=-0.5,y=5,z=-0.5}, --minacc
      {x=0.5,y=5,z=0.5}, --maxacc
      0.1, --minexptime
      1, --maxexptime
      8, --minsize
      15, --maxsize
      false, --collisiondetection
      "tnt_smoke.png" --texture
    )
  end, pos)
end

core.register_node("jc_tnt:tnt", {
  description = "TNT - ONLY USE BELOW -150 METERS - JOIN THEM FOR HUGE BOOM",
  tiles = {"tnt_top.png", "tnt_bottom.png", "tnt_side.png"},
  groups = {dig_immediate=2, mesecon=2},
  sounds = default.node_sound_wood_defaults(),

  on_punch = function(pos, node, puncher)
    if puncher:get_wielded_item():get_name() == "default:torch" then
      if pos.y > -150 then
        return
      end
      core.sound_play("tnt_ignite", {pos=pos})
      core.set_node(pos, {name="jc_tnt:tnt_burning"})
      boom(pos, 4)
    end
  end,
  after_place_node = function(pos, placer)
    local meta = minetest.get_meta(pos);
    meta:set_string("infotext",  "TNT - ONLY USE BELOW -150 METERS - JOIN THEM FOR HUGE BOOM");
  end,

  mesecons = {
    effector = {
      action_on = function(pos, node)
        if pos.y > -150 then
          return
        end
        core.set_node(pos, {name="jc_tnt:tnt_burning"})
        boom(pos, 0)
      end
    },
  },
})

core.register_node("jc_tnt:tnt_burning", {
  tiles = {{name="tnt_top_burning_animated.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=1}}, "tnt_bottom.png", "tnt_side.png"},
  light_source = 5,
  drop = "",
  sounds = default.node_sound_wood_defaults(),
})

core.register_node("jc_tnt:boom", {
  drawtype = "plantlike",
  tiles = {"tnt_boom.png"},
  light_source = core.LIGHT_MAX,
  walkable = false,
  drop = "",
  groups = {dig_immediate=3},
})

burn = function(pos)
  if core.get_node(pos).name == "jc_tnt:tnt" then
    core.sound_play("tnt_ignite", {pos=pos})
    core.set_node(pos, {name="jc_tnt:tnt_burning"})
    boom(pos, 1)
    return
  end
  if core.get_node(pos).name ~= "jc_tnt:gunpowder" then
    return
  end
  core.sound_play("tnt_gunpowder_burning", {pos=pos, gain=2})
  core.set_node(pos, {name="jc_tnt:gunpowder_burning"})

  core.after(1, function(pos)
    if core.get_node(pos).name ~= "jc_tnt:gunpowder_burning" then
      return
    end
    core.after(0.5, function(pos)
      core.remove_node(pos)
    end, {x=pos.x, y=pos.y, z=pos.z})
    for dx=-1,1 do
      for dz=-1,1 do
        for dy=-1,1 do
          pos.x = pos.x+dx
          pos.y = pos.y+dy
          pos.z = pos.z+dz

          if not (math.abs(dx) == 1 and math.abs(dz) == 1) then
            if dy == 0 then
              burn({x=pos.x, y=pos.y, z=pos.z})
            else
              if math.abs(dx) == 1 or math.abs(dz) == 1 then
                burn({x=pos.x, y=pos.y, z=pos.z})
              end
            end
          end

          pos.x = pos.x-dx
          pos.y = pos.y-dy
          pos.z = pos.z-dz
        end
      end
    end
  end, pos)
end

core.register_node("jc_tnt:gunpowder", {
  description = "Gun Powder",
  drawtype = "raillike",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = false,
  tiles = {"tnt_gunpowder.png",},
  inventory_image = "tnt_gunpowder_inventory.png",
  wield_image = "tnt_gunpowder_inventory.png",
  selection_box = {
    type = "fixed",
    fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
  },
  groups = {dig_immediate=2,attached_node=1},
  sounds = default.node_sound_leaves_defaults(),

  on_punch = function(pos, node, puncher)
    if puncher:get_wielded_item():get_name() == "default:torch" then
      burn(pos)
    end
  end,
})

core.register_node("jc_tnt:gunpowder_burning", {
  drawtype = "raillike",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = false,
  light_source = 5,
  tiles = {{name="tnt_gunpowder_burning_animated.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=1}}},
  selection_box = {
    type = "fixed",
    fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
  },
  drop = "",
  groups = {dig_immediate=2,attached_node=1},
  sounds = default.node_sound_leaves_defaults(),
})

core.register_abm({
  nodenames = {"jc_tnt:tnt", "jc_tnt:gunpowder"},
  neighbors = {"fire:basic_flame", "default:lava_source", "default:lava_flowing"},
  interval = 2,
  chance = 10,
  action = function(pos, node)
    if node.name == "jc_tnt:tnt" then
      core.set_node(pos, {name="jc_tnt:tnt_burning"})
      boom({x=pos.x, y=pos.y, z=pos.z}, 0)
    else
      burn(pos)
    end
  end
})

core.register_craft({
  output = "jc_tnt:gunpowder",
  type = "shapeless",
  recipe = {"default:coal_lump", "default:gravel"}
})

core.register_craft({
  output = "jc_tnt:tnt",
  recipe = {
    {"", "group:wood", ""},
    {"group:wood", "jc_tnt:gunpowder", "group:wood"},
    {"", "group:wood", ""}
  }
})

core.register_alias_force("tnt:gunpowder", "jc_tnt:gunpowder")
core.register_alias_force("tnt:gunpowder_burning", "jc_tnt:gunpowder_burning")
core.register_alias_force("tnt:tnt", "jc_tnt:tnt")
core.register_alias_force("tnt:tnt_burning", "jc_tnt:tnt_burning")
core.register_alias_force("tnt:tnt_stick", "jc_tnt:tnt")

-- core.register_on_mods_loaded(function()
  -- if unified_inventory then
    -- unified_inventory.set_inventory_formspec = unified_inventory.set_inventory_formspec
    -- unified_inventory.register_hidden_item("tnt:tnt")
    -- unified_inventory.register_hidden_item("tnt:tnt_stick")
    -- unified_inventory.register_hidden_item("tnt:gunpowder")
    -- unified_inventory.register_hidden_item("tnt:gunpowder_burning")
    -- unified_inventory.register_hidden_item("tnt:tnt_burning")
  -- end
-- end)

core.register_lbm({
  name = "jc_tnt:convert_old_tnt",
  nodenames = {
    "tnt:gunpowder",
    "tnt:gunpowder_burning",
    "tnt:tnt",
    "tnt:tnt_burning",
    "tnt:tnt_stick",
  },
  run_at_every_load = false,
  action = function(pos, node)
    local map = {
      ["tnt:gunpowder"] = "jc_tnt:gunpowder",
      ["tnt:gunpowder_burning"] = "jc_tnt:gunpowder_burning",
      ["tnt:tnt"] = "jc_tnt:tnt",
      ["tnt:tnt_burning"] = "jc_tnt:tnt_burning",
      ["tnt:tnt_stick"] = "jc_tnt:tnt",
    }

    local newname = map[node.name]
    if newname then
      core.swap_node(pos, {name = newname})
    end
  end,
})

if core.settings:get("log_mods") then
  core.log("action", "tnt loaded")
end
