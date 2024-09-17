local _, ts = ...
--- Opts:
---     name (string): Name of the dropdown (lowercase)
---     parent (Frame): Parent frame of the dropdown.
---     items (Table): String table of the dropdown options.
---     defaultVal (String): String value for the dropdown to default to (empty otherwise).
---     changeFunc (Function): A custom function to be called, after selecting a dropdown option.
function ts.CreateDropdown(opts)
    local dropdown_name = '$parent_' .. opts['name'] .. '_dropdown'
    local menu_items = opts['items'] or {}
    local title_text = opts['title'] or ''
    local dropdown_width = opts['width'] or 0
    local default_index = opts['defaultIndex'] or 0
    local change_func = opts['changeFunc'] or function (dropdown_val) end

    local dropdown = CreateFrame("Frame", dropdown_name, opts['parent'], 'UIDropDownMenuTemplate')
    dropdown.opts = opts
    dropdown.menu_items = menu_items
    dropdown.title_text = title_text
    dropdown.default_index = default_index

    UIDropDownMenu_SetWidth(dropdown, dropdown_width)
    UIDropDownMenu_SetText(dropdown, (default_index and default_index > 0) and menu_items[default_index] or title_text)

    function dropdown.ddInit(self, level, _)
        if not level then return end
        local info = UIDropDownMenu_CreateInfo()
        print(level)
        for key, val in pairs(self.menu_items) do
            info.text = val
            info.arg1 = key
            info.isTitle = false
            info.checked = false
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
    if default_index then UIDropDownMenu_SetSelectedID(dropdown, default_index) end

    function dropdown:Remove(index)
        print(self.checked_index)
        if self.checked_index and self.checked_index == index then 
            self.default_index = nil
            self.checked_index = nil
            UIDropDownMenu_SetText(self, self.title_text)
        end
        if self.checked_index and self.checked_index > index then
            self.checked_index = self.checked_index - 1
        end
        tremove(self.menu_items, index)
        UIDropDownMenu_Initialize(self, self.ddInit)
    end

    function dropdown:Add(option)
        table.insert(self.menu_items, option)
        UIDropDownMenu_Initialize(self, self.ddInit)
    end

    function dropdown:Update(options)
        self.menu_items = options
        UIDropDownMenu_Initialize(self, self.ddInit)
    end

    return dropdown
end