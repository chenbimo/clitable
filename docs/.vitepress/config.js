import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'

// `moon.mod` 是下面两个事实的唯一出处:版本号与仓库地址都在构建时读取,
// 页面里不写死版本号——页面是会过期的拷贝,而读的是发布本身。
const moonMod = readFileSync(
  fileURLToPath(new URL('../../moon.mod', import.meta.url)),
  'utf8',
)

function moonModField(name) {
  const found = new RegExp(`^\\s*${name}\\s*=\\s*"([^"]+)"`, 'm').exec(moonMod)
  if (found === null) {
    throw new Error(`docs: cannot read ${name} from moon.mod`)
  }
  return found[1]
}

const version = moonModField('version')
const repository = moonModField('repository')

const sidebar = [
  {
    text: '开始',
    items: [
      { text: '安装与引入', link: '/guide/install' },
      { text: '快速上手', link: '/guide/quickstart' },
    ],
  },
  {
    text: '使用',
    items: [
      { text: '边框、宽度与样式', link: '/guide/features' },
      { text: '单格、跨行与业务类型', link: '/guide/cells' },
    ],
  },
  {
    text: '参考',
    items: [{ text: '设计与语义', link: '/guide/design' }],
  },
]

export default defineConfig({
  // 站点挂在 https://clitable.moonbitlang.dev 这个子域名下,是根路径,所以 base
  // 为 '/'。这是部署形态唯一的切换点:换回子路径部署时,这里要和路径前缀一致,
  // 否则资源与内部链接会指向站点根,打开就是白屏。
  base: '/',
  lang: 'zh-CN',
  title: 'clitable',
  description: '用 MoonBit 写的终端表格渲染库。',
  cleanUrls: true,
  outDir: 'dist',
  themeConfig: {
    socialLinks: [{ icon: 'github', link: repository }],
    nav: [
      // 官网门户入口:每个页面顶栏都能一键回到 moonbitlang.dev。
      { text: 'Moonkit 官网', link: 'https://moonbitlang.dev' },
      { text: '指南', link: '/guide/install' },
      { text: `v${version}`, link: `${repository}/releases` },
    ],
    sidebar: { '/guide/': sidebar },
    outline: { label: '本页目录', level: [2, 3] },
    docFooter: { prev: '上一页', next: '下一页' },
    lastUpdated: { text: '最后更新' },
    darkModeSwitchLabel: '外观',
    sidebarMenuLabel: '目录',
    returnToTopLabel: '回到顶部',
  },
})
