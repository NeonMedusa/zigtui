import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  docsSidebar: [
    {
      type: "doc",
      id: "getting-started",
      label: "Getting Started",
    },
    {
      type: "doc",
      id: "layout",
      label: "Layout",
    },
    {
      type: "doc",
      id: "events",
      label: "Events and Input",
    },
    {
      type: "category",
      label: "Widgets",
      collapsed: false,
      items: [
        "widgets/block",
        "widgets/paragraph",
        "widgets/list",
        "widgets/gauge",
        "widgets/table",
        "widgets/tabs",
        "widgets/sparkline",
        "widgets/bar-chart",
        "widgets/text-input",
        "widgets/choice-controls",
        "widgets/date-picker",
        "widgets/spinner",
        "widgets/tree",
        "widgets/canvas",
        "widgets/popup",
        "widgets/dialog",
      ],
    },
    {
      type: "doc",
      id: "themes",
      label: "Themes",
    },
    {
      type: "doc",
      id: "unicode",
      label: "Unicode",
    },
    {
      type: "doc",
      id: "kitty-graphics",
      label: "Kitty Graphics",
    },
    {
      type: "doc",
      id: "platform-support",
      label: "Platform Support",
    },
  ],
};

export default sidebars;
