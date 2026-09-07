import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import {
  DynamicBorder,
  getAgentDir,
  getSettingsListTheme,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Container, Text } from "@earendil-works/pi-tui";
import {
  SectionedSettingsList,
  type SectionedSettingRow,
} from "./sectioned-settings-list.ts";

const REGISTRY_SYMBOL = Symbol.for("@99percentpeople/pi-shared-settings/registry-v1");
const COMMAND_NAME = "99settings";
const MAX_VISIBLE_SETTINGS_ROWS = 10;

export interface ExtensionSetting {
  id: string;
  label: string;
  description: string;
  currentValue: string;
  values?: string[];
  submenu?: ExtensionSettingsPanel;
}

export interface ExtensionSettingsPanel {
  title: string;
  currentValue?(): string;
  settings(): ExtensionSetting[];
  onChange?(id: string, value: string, ctx: ExtensionContext): void;
}

export interface ExtensionSettingsSection {
  namespace: string;
  title: string;
  settings(): ExtensionSetting[];
  onChange?(id: string, value: string, ctx: ExtensionContext): void;
}

interface RegisteredSection extends ExtensionSettingsSection {
  owner: symbol;
}

interface SharedSettingsRegistry {
  commandRegistered: boolean;
  sections: Map<string, RegisteredSection>;
}

type SettingsDocument = Record<string, unknown>;

const globalRegistry = globalThis as typeof globalThis & {
  [REGISTRY_SYMBOL]?: SharedSettingsRegistry;
};

function getRegistry(): SharedSettingsRegistry {
  globalRegistry[REGISTRY_SYMBOL] ??= {
    commandRegistered: false,
    sections: new Map(),
  };
  return globalRegistry[REGISTRY_SYMBOL];
}

export function getSharedSettingsPath(): string {
  return join(getAgentDir(), "99extensions.json");
}

function loadDocument(path: string): SettingsDocument {
  try {
    const value: unknown = JSON.parse(readFileSync(path, "utf8"));
    return value && typeof value === "object" && !Array.isArray(value)
      ? (value as SettingsDocument)
      : {};
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ENOENT" || error instanceof SyntaxError) return {};
    throw error;
  }
}

function assertNamespace(namespace: string): void {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(namespace)) {
    throw new Error(`Invalid settings namespace: ${namespace}`);
  }
}

export function readSettingsNamespace<T>(
  namespace: string,
  normalize: (value: unknown) => T,
  path = getSharedSettingsPath(),
): T {
  assertNamespace(namespace);
  return normalize(loadDocument(path)[namespace]);
}

export function writeSettingsNamespace<T>(
  namespace: string,
  value: T,
  path = getSharedSettingsPath(),
): void {
  assertNamespace(namespace);
  const document = loadDocument(path);
  document[namespace] = value;
  mkdirSync(dirname(path), { recursive: true });
  const temporaryPath = `${path}.${process.pid}.tmp`;
  writeFileSync(temporaryPath, `${JSON.stringify(document, null, 2)}\n`, "utf8");
  renameSync(temporaryPath, path);
}

interface MenuRow {
  section: RegisteredSection;
  setting?: ExtensionSetting;
}

async function showSettingsMenu(ctx: ExtensionContext, registry: SharedSettingsRegistry): Promise<void> {
  if (ctx.mode !== "tui") {
    ctx.ui.notify(`/${COMMAND_NAME} requires TUI mode`, "error");
    return;
  }

  const sections = [...registry.sections.values()]
    .filter((section) => section.settings().length > 0)
    .sort((left, right) => left.title.localeCompare(right.title));
  if (sections.length === 0) {
    ctx.ui.notify("No configurable @99percentpeople extension settings are currently available", "info");
    return;
  }

  await ctx.ui.custom((tui, theme, _keybindings, done) => {
    const createPanel = (
      panel: ExtensionSettingsPanel,
      close: (value?: string) => void,
    ) => {
      let list: SectionedSettingsList;
      const buildRows = (): SectionedSettingRow[] =>
        panel.settings().map((setting) => ({
          id: setting.id,
          section: panel.title,
          label: setting.label,
          description: setting.description,
          currentValue: setting.currentValue,
          values: setting.values,
          submenu: setting.submenu
            ? (_current, done) => createPanel(setting.submenu!, done)
            : undefined,
        }));
      list = new SectionedSettingsList(
        buildRows(),
        MAX_VISIBLE_SETTINGS_ROWS,
        {
          ...getSettingsListTheme(),
          header: (text) => theme.fg("accent", theme.bold(text)),
        },
        (id, value) => {
          panel.onChange?.(id, value, ctx);
          list.replaceRows(buildRows(), id);
        },
        () => close(panel.currentValue?.()),
      );
      return list;
    };

    const menuRows = new Map<string, MenuRow>();
    const buildRootRows = (): SectionedSettingRow[] => {
      menuRows.clear();
      const rows: SectionedSettingRow[] = [];
      for (const section of sections) {
        const settings = section.settings();
        for (const setting of settings) {
          const id = `${section.namespace}:${setting.id}`;
          menuRows.set(id, { section, setting });
          rows.push({
            id,
            section: section.title,
            label: setting.label,
            description: setting.description,
            currentValue: setting.currentValue,
            values: setting.values,
            submenu: setting.submenu
              ? (_current, done) => createPanel(setting.submenu!, done)
              : undefined,
          });
        }
      }
      return rows;
    };

    const container = new Container();
    const border = new DynamicBorder((text: string) => theme.fg("accent", text));
    container.addChild(border);
    container.addChild(new Text(theme.fg("accent", theme.bold("99 Extensions Settings")), 1, 0));
    const listTheme = getSettingsListTheme();
    const settingsList = new SectionedSettingsList(
      buildRootRows(),
      MAX_VISIBLE_SETTINGS_ROWS,
      {
        ...listTheme,
        header: (text) => theme.fg("accent", theme.bold(text)),
      },
      (id, value) => {
        const row = menuRows.get(id);
        if (!row?.setting || !row.section.onChange) return;
        row.section.onChange(row.setting.id, value, ctx);
        settingsList.replaceRows(buildRootRows(), id);
      },
      () => done(undefined),
    );
    container.addChild(settingsList);
    container.addChild(border);

    return {
      render: (width: number) => container.render(width),
      invalidate: () => container.invalidate(),
      handleInput: (data: string) => {
        settingsList.handleInput(data);
        tui.requestRender();
      },
    };
  });
}

function ensureCommand(pi: ExtensionAPI, registry: SharedSettingsRegistry): void {
  if (registry.commandRegistered) return;
  registry.commandRegistered = true;
  pi.registerCommand(COMMAND_NAME, {
    description: "Configure installed @99percentpeople extensions",
    handler: async (_args, ctx) => showSettingsMenu(ctx, registry),
  });
}

export function registerExtensionSettings(
  pi: ExtensionAPI,
  section: ExtensionSettingsSection,
): void {
  assertNamespace(section.namespace);
  const registry = getRegistry();
  const owner = Symbol(section.namespace);
  registry.sections.set(section.namespace, { ...section, owner });
  ensureCommand(pi, registry);

  pi.on("session_shutdown", () => {
    const current = registry.sections.get(section.namespace);
    if (current?.owner === owner) registry.sections.delete(section.namespace);
    if (registry.sections.size === 0) {
      registry.commandRegistered = false;
      delete globalRegistry[REGISTRY_SYMBOL];
    }
  });
}

export const SHARED_SETTINGS_COMMAND = COMMAND_NAME;
