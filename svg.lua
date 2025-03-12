
Svg = {
    standard_css = 'z1.css',
    standard_svg_template = 'z1.temp.svg',
    content = ""
}

function Svg:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Svg:line(ax, ay, bx, by, className)
    if className == nil then className = 'ligation' end

    s = string.format('<line class="%s" x1="%2.f" y1="%.2f" x2="%.2f" y2="%.2f"></line>', className, ax, ay, bx, by)
    self.content = self.content .. s
end

function Svg:text(symbol, x, y)
    s = string.format('<text class="element element-%s" x="%.2f" y="%.2f">%s</text>', symbol, x, y, symbol)
    self.content = self.content .. s
end

function Svg:subtext(symbol, x, y)
    s = string.format('<text class="element-charge" x="%.2f" y="%.2f">%s</text>', x, y, symbol)
    self.content = self.content .. s
end

function Svg:build(width, height)
    css_file = io.open(self.standard_css, "r")
    css = css_file:read("*a")
    css = css:gsub("[\n|\t]","")
    io.close(css_file)

    svg_template_file = io.open(self.standard_svg_template, "r")
    svg_template = svg_template_file:read("*a")
    io.close(svg_template_file)

    svg = string.format(svg_template, width, height, css, self.content)
    return svg
end