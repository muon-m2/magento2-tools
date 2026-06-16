# Uploaders & WYSIWYG

## WYSIWYG (resolves "content renders as a plain textarea")

`formElement="wysiwyg"` plus `<wysiwyg>true</wysiwyg>` and a `wysiwygConfigData` block gives the
canonical rich-text field. It depends on `Magento_Cms` (bundled in both editions). ([S12], field-types.md)

```xml
<field name="content" formElement="wysiwyg">
    <argument name="data" xsi:type="array">
        <item name="config" xsi:type="array">
            <item name="source" xsi:type="string">{entity}</item>
            <item name="wysiwygConfigData" xsi:type="array">
                <item name="height" xsi:type="string">200px</item>
                <item name="add_variables" xsi:type="boolean">false</item>
                <item name="add_widgets" xsi:type="boolean">false</item>
                <item name="add_images" xsi:type="boolean">true</item>
            </item>
        </item>
    </argument>
    <settings><dataType>text</dataType><label translate="true">Content</label><wysiwyg>true</wysiwyg></settings>
    <formElements><wysiwyg><settings><rows>8</rows><wysiwyg>true</wysiwyg></settings></wysiwyg></formElements>
</field>
```

Set `add_widgets`/`add_variables`/`add_directives` to `true` only when the entity should support CMS
widgets/variables (these add toolbar buttons).

## Image / file uploader (resolves "uploader shows path not preview")

`formElement="imageUploader"` (or `fileUploader`) pairs with an **upload controller**. The field's
`uploaderConfig/url` points at that controller; the DataProvider must convert the stored string path
into the `{name, url, size, type}` array the component expects on load — otherwise the field shows the
raw path, not a thumbnail. ([S12])

Wiring checklist:
1. Field: `formElement="imageUploader"` with `<uploaderConfig><param name="url" xsi:type="url" path="{vendor_lower}_{entity}/{entity}_image/upload"/></uploaderConfig>`.
2. Upload controller (`Controller/Adminhtml/{Entity}Image/Upload.php`) using
   `Magento\Catalog\Model\ImageUploader` or `Magento\MediaStorage\Model\File\UploaderFactory` to save
   into a media subdir and return JSON.
3. DataProvider: in `getData()`, map the stored path → `[['name'=>…, 'url'=>$mediaUrl.$path, …]]`.
4. On Save: flatten the uploader array back to the stored path before `repository->save()`.

This uploader surface is more involved than text fields — generate it only when requested.

## Sources
- [S12] Adobe — Image uploader component: https://developer.adobe.com/commerce/frontend-core/ui-components/components/image-uploader
