-- moran_semicolon_processor.lua
-- Synopsis: 選擇第二個首選項，但可用於跳過 emoji 濾鏡產生的候選
-- Author: ksqsf
-- License: MIT license
-- Version: 0.1.5

-- ChangeLog:
--  0.1.5: 修復獲取 candidate_count 的邏輯
--  0.1.4: 數字也增加到條件裏

-- NOTE: This processor depends on, and thus should be placed before,
-- the built-in "selector" processor.

local moran = require("moran")

local kReject = 0
local kAccepted = 1
local kNoop = 2

local function processor(key_event, env)
   local context = env.engine.context

   if key_event.keycode ~= 0x3B or key_event:release() then
      return kNoop
   end

   local composition = context.composition
   if composition:empty() then
      return kNoop
   end

   local segment = composition:back()
   local menu = segment.menu
   local page_size = env.engine.schema.page_size

   -- Special cases: for 'ovy' and 快符, just send ';'
   if context.input:find('^ovy') or context.input:find('^;') then
      return kNoop
   end

   -- Special case: if there is only one candidate, just select it!
   local candidate_count = menu:prepare(page_size)
   if candidate_count == 1 then
      context:select(0)
      return kAccepted
   end

   -- If it is not the first page, simply send 2.
   local selected_index = segment.selected_index
   if selected_index >= page_size then
      local page_num = selected_index // page_size
      context:select(page_num * page_size + 1)
      return kAccepted
   end

   -- First page: do something more sophisticated.
   local i = 1
   while i < page_size do
      local cand = menu:get_candidate_at(i)
      if cand == nil then
         context:select(1)
         return kNoop
      end
      local cand_text = cand.text
      local codepoint = utf8.codepoint(cand_text, 1)
      if moran.unicode_code_point_is_chinese(codepoint) -- 漢字
         or (codepoint >= 97 and codepoint <= 122)      -- a-z
         or (codepoint >= 65 and codepoint <= 90)       -- A-Z
         or (codepoint >= 48 and codepoint <= 57 and cand.type ~= "simplified") -- 0-9
      then
         context:select(i)
         return kAccepted
      end
      i = i + 1
   end

   -- No good candidates found. Just select the second candidate.
   context:select(1)
   return kAccepted
end

return processor
