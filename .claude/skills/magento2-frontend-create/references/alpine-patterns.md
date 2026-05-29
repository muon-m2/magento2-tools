# Alpine.js Patterns (Hyva)

Hyva replaces Knockout with Alpine.js. The skill generates Alpine components when the
detected theme is Hyva.

## Inline Component

```html
<!-- view/frontend/templates/my-component.phtml -->
<div x-data="myComponent(<?= $block->escapeHtmlAttr(json_encode($payload)) ?>)" x-cloak>
    <h2 x-text="label"></h2>
    <button @click="setLabel('Clicked')">Click</button>
</div>

<script>
    function myComponent(payload) {
        return {
            label: payload.label || '',
            setLabel(text) { this.label = text; }
        };
    }
</script>
```

## External Component (Reusable)

```js
// view/frontend/web/js/my-component.js
function myComponent(payload) {
    return {
        label: payload.label || '',
        setLabel(text) { this.label = text; }
    };
}
window.myComponent = myComponent;
```

Register in `view.xml` or include via `<script>` in the layout.

## Hyva Tailwind Conventions

```html
<button class="bg-primary hover:bg-primary-darker text-white px-4 py-2 rounded">
    Click
</button>
```

Use Tailwind utility classes; avoid custom CSS unless necessary. Hyva ships a curated
Tailwind config; reference its `tailwind.config.js`.

## Magewire (Hyva Reactive Components)

For server-side reactive components, Hyva ships Magewire (similar to Laravel Livewire):

```php
// app/code/{Vendor}/{Module}/Magewire/MyComponent.php
namespace {Vendor}\{Module}\Magewire;

use Magewirephp\Magewire\Component;

class MyComponent extends Component
{
    public string $label = '';

    public function setLabel(string $text): void
    {
        $this->label = $text;
    }
}
```

```html
<!-- view/frontend/templates/magewire/my-component.phtml -->
<div>
    <h2><?= $this->escapeHtml($label) ?></h2>
    <button wire:click="setLabel('Clicked')">Click</button>
</div>
```

## Common Mistakes

- Forgetting `x-cloak` — content flashes before Alpine initializes.
- Using `data-bind` (Knockout) inside Hyva templates — silently ignored.
- Loading jQuery in Hyva — bloats the bundle; use Alpine + vanilla.
