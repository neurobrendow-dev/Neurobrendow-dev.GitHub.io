# Implementação do Jekyll no seu site (GitHub Pages)

Este guia mostra como adicionar um blog em Jekyll ao seu landing page existente, mantendo o `index.html` atual praticamente intacto.

---

## Estrutura de arquivos final

Sua pasta do repositório ficará assim:

```
seu-repositorio/
├── _config.yml                ← NOVO (configuração do Jekyll)
├── Gemfile                    ← NOVO (dependências)
├── .gitignore                 ← NOVO
├── _layouts/                  ← NOVO
│   ├── default.html
│   ├── post.html
│   └── blog.html
├── _posts/                    ← NOVO (seus artigos em Markdown)
│   ├── 2026-03-30-saude-cerebral-habitos-diarios.md
│   ├── 2026-04-15-enxaqueca-tratamentos-modernos.md
│   └── 2026-04-28-quando-procurar-um-neurologista.md
├── blog/
│   └── index.html             ← NOVO (página de listagem)
├── index.html                 ← MODIFICAR (adicionar 2 linhas, ver abaixo)
├── favicon.ico                ← já existe
└── (suas imagens, etc.)       ← já existem
```

---

## Passo 1 — Copiar os arquivos novos para o repositório

Copie todos os arquivos desta pasta de saída para a raiz do seu repositório no GitHub, mantendo a estrutura de pastas (`_layouts/`, `_posts/`, `blog/`).

---

## Passo 2 — Modificar o seu `index.html`

Você precisa fazer **duas pequenas alterações** no `index.html` que já existe:

### 2.1 — Adicionar front matter no topo

Bem no início do arquivo, **antes** da linha `<!DOCTYPE html>`, adicione:

```yaml
---
layout: null
permalink: /
---
```

Isso faz o Jekyll processar o arquivo (para que os links `{{ ... }}` funcionem se você quiser usá-los), mas **sem** aplicar layout — ou seja, seu HTML continua exatamente como está.

### 2.2 — Adicionar o link "Blog" no menu

Localize o bloco `<ul class="nav-links">` (linha ~795 do seu HTML) e adicione um `<li>` para o blog:

**Antes:**
```html
<ul class="nav-links">
  <li><a href="#sobre">Sobre</a></li>
  <li><a href="#especialidades">Especialidades</a></li>
  <li><a href="#diferenciais">Diferenciais</a></li>
  <li><a href="#depoimentos">Depoimentos</a></li>
  <li><a href="#contato" class="nav-cta">Agendar Consulta</a></li>
</ul>
```

**Depois:**
```html
<ul class="nav-links">
  <li><a href="#sobre">Sobre</a></li>
  <li><a href="#especialidades">Especialidades</a></li>
  <li><a href="#diferenciais">Diferenciais</a></li>
  <li><a href="#depoimentos">Depoimentos</a></li>
  <li><a href="/blog/">Blog</a></li>
  <li><a href="#contato" class="nav-cta">Agendar Consulta</a></li>
</ul>
```

(Opcional, mas recomendado) faça o mesmo no `<footer>`, no bloco "Navegação".

---

## Passo 3 — Ativar Jekyll no GitHub Pages

1. Acesse seu repositório no GitHub.
2. Vá em **Settings → Pages**.
3. Em **Build and deployment → Source**, escolha **Deploy from a branch**.
4. Selecione a branch `main` (ou `master`) e a pasta `/ (root)`.
5. Clique em **Save**.

O GitHub vai detectar o `_config.yml` automaticamente e fazer o build com Jekyll. Em 1–2 minutos seu site estará no ar com o blog em `https://SEU-DOMINIO/blog/`.

> **Observação:** Se você usa um domínio customizado (ex: `drbrendowmartin.com.br`), atualize a chave `url` no `_config.yml` para refletir isso.

---

## Passo 4 — Testar localmente (opcional, mas útil)

Para ver o site rodando no seu computador antes de subir mudanças:

### Pré-requisitos
- **Ruby 3.1+** instalado
- **Bundler**: `gem install bundler`

### Comandos

```bash
# Na raiz do repositório
bundle install            # instala as dependências (1ª vez apenas)
bundle exec jekyll serve  # inicia o servidor local
```

Abra no navegador: `http://localhost:4000`

O servidor faz hot-reload — sempre que você editar um arquivo, basta atualizar a página.

---

## Como criar um novo post

Crie um arquivo em `_posts/` com o nome no formato:

```
AAAA-MM-DD-titulo-do-post.md
```

Exemplo: `_posts/2026-05-10-avc-reconhecer-os-sinais.md`

E inclua o seguinte cabeçalho (front matter) no topo do arquivo:

```yaml
---
layout: post
title: "AVC: como reconhecer os sinais nos primeiros minutos"
description: "O que você precisa saber para agir rápido diante de um AVC."
date: 2026-05-10 09:00:00 -0300
category: "Emergências"
tags: [avc, emergência, prevenção]
reading_time: 5
cover: /assets/img/posts/avc-cover.jpg   # opcional
---

Conteúdo do post em **Markdown**...

## Subtítulo

Texto normal, listas, links, imagens, etc.
```

Depois é só fazer commit e push — o GitHub Pages publica automaticamente.

---

## Sobre o design

- O blog usa **as mesmas cores, fontes e estilo** do landing page (tons navy, dourado, Cormorant Garamond + DM Sans).
- A navbar é a mesma em todas as páginas, com o `index.html` mantendo a versão original e as páginas do blog usando o `_layouts/default.html`.
- O Meta Pixel e o Google Analytics estão configurados também nas páginas do blog.

---

## SEO incluído

Já vem configurado:
- `jekyll-seo-tag` — gera meta tags Open Graph e Twitter Card automaticamente
- `jekyll-feed` — gera um feed RSS em `/feed.xml`
- `jekyll-sitemap` — gera `/sitemap.xml` para o Google
- `jekyll-paginate` — divide o blog em páginas de 6 posts

---

## Resumo dos comandos importantes

| Ação | Comando |
|------|---------|
| Instalar dependências | `bundle install` |
| Servidor local | `bundle exec jekyll serve` |
| Build de produção | `bundle exec jekyll build` |
| Atualizar gems | `bundle update` |

Qualquer dúvida na implementação, é só me chamar.
