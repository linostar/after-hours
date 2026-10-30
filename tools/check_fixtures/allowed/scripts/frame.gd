extends TextureRect
## Allowed: words that only look like text classes (a TextureRect, the SceneTree,
## the context of a get_tree() call) and a comparison with a Button's text.


func context_of(tree: SceneTree, button: Button) -> bool:
	return tree == get_tree() and button.text == ""
