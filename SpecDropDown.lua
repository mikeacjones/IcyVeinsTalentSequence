local _, ts = ...
--- Opts:
---     name (string): Name of the dropdown (lowercase)
---     parent (Frame): Parent frame of the dropdown.
---     items (Table): String table of the dropdown options.
---     defaultVal (String): String value for the dropdown to default to (empty otherwise).
---     changeFunc (Function): A custom function to be called, after selecting a dropdown option.
function ts.CreateDropdown(opts)
    local dropdown_name = '$parent_' .. opts['name'] .. '_dropdown'
    local menu_items = {}
    if opts['items'] then
        menu_items = {} for k, v in pairs(opts['items']) do menu_items[k] = v end
    end
    local title_text = opts['title'] or ''
    local dropdown_width = opts['width'] or 0
    local default_index = opts['defaultIndex'] or nil
    local change_func = opts['changeFunc'] or function (dropdown_val) end

    local dropdown = CreateFrame("Frame", dropdown_name, opts['parent'], 'UIDropDownMenuTemplate')
    dropdown.opts = opts
    dropdown.menu_items = menu_items
    dropdown.title_text = title_text
    dropdown.checked_index = default_index
    dropdown.dropdown_name = dropdown_name

    UIDropDownMenu_SetWidth(dropdown, dropdown_width)
    function dropdown.ddInit(self, level, _)
        if not level then return end
        local info = UIDropDownMenu_CreateInfo()
        for key, val in pairs(self.menu_items) do
            info.text = val
            info.arg1 = key
            info.isTitle = false
            info.checked = key == self.checked_index
            info.menuList = false
            info.hasArrow = false
            info.owner = self

            info.func = function(self2, arg1)
                UIDropDownMenu_SetSelectedID(self, arg1)
                UIDropDownMenu_SetText(self, self2.value)
                self.checked_index = arg1
                change_func(self, self2.value, arg1)
            end

            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, dropdown.ddInit, nil, 1)
    if dropdown.checked_index and dropdown.checked_index > 0 and dropdown.checked_index <= #menu_items then 
        UIDropDownMenu_SetSelectedID(dropdown, dropdown.checked_index)
        UIDropDownMenu_SetText(dropdown, dropdown.menu_items[dropdown.checked_index])
    else
        UIDropDownMenu_SetText(dropdown, dropdown.title_text)
    end

    function dropdown:Remove(index)
        if self.checked_index and self.checked_index == index then self.checked_index = nil end
        if self.checked_index and self.checked_index > index then self.checked_index = self.checked_index - 1 end

        table.remove(self.menu_items, index)
        UIDropDownMenu_Initialize(self, self.ddInit)

        UIDropDownMenu_SetSelectedID(self, self.checked_index)
        UIDropDownMenu_SetText(self, self.menu_items[self.checked_index] or self.title_text)
    end

    function dropdown:Update(options)
        if #options > #self.menu_items then
            if self.checked_index and self.checked_index > 0 then self.checked_index = self.checked_index + 1 end
        end
        self.menu_items = {} for k, v in pairs(options) do self.menu_items[k] = v end
        
        if self.checked_index and self.checked_index > 0 and self.checked_index <= #self.menu_items then
            UIDropDownMenu_SetSelectedID(self, self.checked_index)
            UIDropDownMenu_SetText(self, self.menu_items[self.checked_index])
        else
            UIDropDownMenu_SetText(self, self.title_text)
        end
    end

    return dropdown
end