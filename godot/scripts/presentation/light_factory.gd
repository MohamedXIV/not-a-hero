extends RefCounted
## Shared small 2D light texture so interior and machine fixtures render similarly.

static func radial_texture() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
    gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    texture.width = 256
    texture.height = 256
    return texture
