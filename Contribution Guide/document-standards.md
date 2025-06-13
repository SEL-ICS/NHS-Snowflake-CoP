# 📄 Document standards

This guide outlines the standards for contributing Markdown documentation to the Snowflake Community of Practice repository. Following these conventions ensures consistency, readability, and ease of collaboration.

## Contents

- [📄 Document standards](#%F0%9F%93%84-document-standards)
  - [Contents](#contents)
  - [📃 File naming conventions](#%F0%9F%93%83-file-naming-conventions)
  - [📁 Folder structure](#%F0%9F%93%81-folder-structure)
  - [⬇️ Markdown formatting and linting](#%E2%AC%87%EF%B8%8F-markdown-formatting-and-linting)
    - [Titles](#titles)
    - [Bullet points](#bullet-points)
    - [Code](#code)
  - [🔊 Tone and Style](#%F0%9F%94%8A-tone-and-style)
  - [💻 Code and SQL Standards](#%F0%9F%92%BB-code-and-sql-standards)
  - [🖼️ Images and Diagrams](#%F0%9F%96%BC%EF%B8%8F-images-and-diagrams)
  - [🛡️ Badges and Shields](#%F0%9F%9B%A1%EF%B8%8F-badges-and-shields)
  - [🔗 Linking](#%F0%9F%94%97-linking)
  - [🔍 Review and Approval](#%F0%9F%94%8D-review-and-approval)


## 📃 File naming conventions

- Use lowercase letters and hyphens (`-`) for file names.
- Avoid spaces, underscores, or special characters.
- File names should clearly reflect the topic (e.g., `zero-copy-cloning.md`).

## 📁 Folder structure

All Content shall be organised into the agreed folders:

- `snowflake-basics/`
- `contribution-guide/`
- `snowflake-tips/`
- `snowsight-tips/`
- `native-features/`

## ⬇️ Markdown formatting and linting

### Titles

- Use `#` for titles, `##` for subtitles, etc.
- Titles should be written in Sentence casing, i.e. subsequent words that are not proper nouns should not be capitalised.


### Bullet points

Use `-` or `*` for unordered bullet points.

Use `1` for all ordered bullet points. Do **not** use `2.`, `3.` etc. for the subsequent values, instead continue to type `1.`. Markdown will resolve the ordered list when rendering to the user.

### Code

- Use backticks for inline code: \`example\` (to display as `example`)
- Use triple backticks for code blocks

> [!TIP]
> When using tiple backticks, ensure that you include the language to higlight the key words
> for example:
> ````md
> ```sql
>  SELECT * FROM my_table;
> ```
> ````
> will display as
> ```sql
> SELECT * FROM my_table;
> ```

## 🔊 Tone and Style
- Write in a clear, concise, and friendly tone.
- Use active voice where possible.
- Avoid jargon unless explained.
- Ensure **all **acronyms are introduced with the full term explained.

## 💻 Code and SQL Standards

These standards apply when sharing code, or including example code for tips and guides.

- Use uppercase for SQL keywords (`SELECT`, `FROM`, `WHERE`).
- Use lowercase for table and column names unless otherwise required.
- Include comments in code blocks where helpful.

## 🖼️ Images and Diagrams

- All images and assets must be stored in a sub-folder named `images/` or `assets/` beneath the folder where the respective markdown file is stored.
- Use relative paths (not fully declared paths) to link images.
- Include alt text for accessibility:

Alt-text is contained inside the square brackets of your links
````markdown
  ![Zero Copy Clone Diagram](../images/zero-copy-clone.png)
````

## 🛡️ Badges and Shields

Consider using Shields.io badges for visual cues:

```markdown
![Markdown](https://img.shields.io/badge/docs-markdown-blue?logo=markdown)
```

## 🔗 Linking
- Use relative links for internal navigation:

```markdown
  [Go to Snowflake Tips](../snowflake-tips/zero-copy-clone.md)
```

## 🔍 Review and Approval

- All contributions **must** go through a pull request and be peer-reviewed
- All PRs must be free of conflicts, authors are strongly advised to pull down changes from main before raising their pull requests.
- Ensure peer review before merging to `main`.

---
Thank you for helping maintain high-quality documentation!
