local specs = {
  require("tests.specs.model_spec"),
  require("tests.specs.navigation_spec"),
  require("tests.specs.editor_spec"),
  require("tests.specs.layout_spec"),
  require("tests.specs.bufferline_spec"),
}

local count = 0
for _, spec in ipairs(specs) do
  for _, test in ipairs(spec) do
    test()
    count = count + 1
  end
end

print(("tests-ok:%d"):format(count))
