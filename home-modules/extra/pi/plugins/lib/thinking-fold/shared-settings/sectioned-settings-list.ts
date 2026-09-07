import {
  getKeybindings,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
  type Component,
  type SettingsListTheme,
} from "@earendil-works/pi-tui";

export interface SectionedSettingRow {
  id: string;
  section: string;
  label: string;
  description?: string;
  currentValue: string;
  values?: string[];
  submenu?: (currentValue: string, done: (value?: string) => void) => Component;
}

export interface SectionedSettingsListTheme extends SettingsListTheme {
  header(text: string): string;
}

export class SectionedSettingsList implements Component {
  private selectedIndex = 0;
  private submenuComponent: Component | undefined;
  private submenuRowId: string | undefined;

  constructor(
    private rows: SectionedSettingRow[],
    private readonly maxVisibleRows: number,
    private readonly theme: SectionedSettingsListTheme,
    private readonly onChange: (id: string, value: string) => void,
    private readonly onCancel: () => void,
  ) {}

  replaceRows(rows: SectionedSettingRow[], selectedId?: string): void {
    const currentId = selectedId ?? this.rows[this.selectedIndex]?.id;
    this.rows = rows;
    const nextIndex = currentId ? rows.findIndex((row) => row.id === currentId) : -1;
    this.selectedIndex = nextIndex >= 0 ? nextIndex : Math.min(this.selectedIndex, Math.max(0, rows.length - 1));
  }

  updateValue(id: string, value: string): void {
    const row = this.rows.find((candidate) => candidate.id === id);
    if (row) row.currentValue = value;
  }

  invalidate(): void {
    this.submenuComponent?.invalidate?.();
  }

  render(width: number): string[] {
    if (this.submenuComponent) return this.submenuComponent.render(width);
    if (this.rows.length === 0) {
      return [this.theme.hint("  No settings available"), "", this.renderHint(width)];
    }

    const visibleCount = Math.max(1, this.maxVisibleRows);
    const start = Math.max(
      0,
      Math.min(
        this.selectedIndex - Math.floor(visibleCount / 2),
        this.rows.length - visibleCount,
      ),
    );
    const end = Math.min(start + visibleCount, this.rows.length);
    const visibleRows = this.rows.slice(start, end);
    const maxLabelWidth = Math.min(
      30,
      Math.max(...this.rows.map((row) => visibleWidth(row.label))),
    );
    const lines: string[] = [];
    let previousSection: string | undefined;

    for (let offset = 0; offset < visibleRows.length; offset += 1) {
      const row = visibleRows[offset]!;
      const rowIndex = start + offset;
      if (row.section !== previousSection) {
        lines.push(truncateToWidth(this.theme.header(`  ${row.section}`), width));
        previousSection = row.section;
      }

      const selected = rowIndex === this.selectedIndex;
      const prefix = selected ? this.theme.cursor : "  ";
      const label = truncateToWidth(row.label, maxLabelWidth, "");
      const labelPadded = label + " ".repeat(Math.max(0, maxLabelWidth - visibleWidth(label)));
      const separator = "  ";
      const usedWidth =
        visibleWidth(prefix) +
        maxLabelWidth +
        visibleWidth(separator);
      const valueWidth = Math.max(0, width - usedWidth - 2);
      const value = truncateToWidth(row.currentValue, valueWidth, "");
      lines.push(
        truncateToWidth(
          prefix +
            this.theme.label(labelPadded, selected) +
            separator +
            this.theme.value(value, selected),
          width,
        ),
      );
    }

    if (start > 0 || end < this.rows.length) {
      lines.push(this.theme.hint(`  (${this.selectedIndex + 1}/${this.rows.length})`));
    }

    const selectedRow = this.rows[this.selectedIndex];
    if (selectedRow?.description) {
      lines.push("");
      for (const line of wrapTextWithAnsi(selectedRow.description, Math.max(1, width - 4))) {
        lines.push(this.theme.description(`  ${line}`));
      }
    }
    lines.push("");
    lines.push(this.renderHint(width));
    return lines;
  }

  handleInput(data: string): void {
    if (this.submenuComponent) {
      this.submenuComponent.handleInput?.(data);
      return;
    }
    const keybindings = getKeybindings();
    if (keybindings.matches(data, "tui.select.up")) {
      if (this.rows.length > 0) {
        this.selectedIndex = this.selectedIndex === 0 ? this.rows.length - 1 : this.selectedIndex - 1;
      }
      return;
    }
    if (keybindings.matches(data, "tui.select.down")) {
      if (this.rows.length > 0) {
        this.selectedIndex =
          this.selectedIndex === this.rows.length - 1 ? 0 : this.selectedIndex + 1;
      }
      return;
    }
    if (keybindings.matches(data, "tui.select.cancel")) {
      this.onCancel();
      return;
    }
    if (keybindings.matches(data, "tui.select.confirm") || data === " ") {
      const row = this.rows[this.selectedIndex];
      if (row?.submenu) {
        this.submenuRowId = row.id;
        this.submenuComponent = row.submenu(row.currentValue, (value) => {
          if (value !== undefined) {
            row.currentValue = value;
            this.onChange(row.id, value);
          }
          this.submenuComponent = undefined;
          const restoredIndex = this.rows.findIndex((candidate) => candidate.id === this.submenuRowId);
          if (restoredIndex >= 0) this.selectedIndex = restoredIndex;
          this.submenuRowId = undefined;
        });
        return;
      }
      if (!row?.values || row.values.length === 0) return;
      const currentIndex = row.values.indexOf(row.currentValue);
      const value = row.values[(currentIndex + 1) % row.values.length]!;
      row.currentValue = value;
      this.onChange(row.id, value);
    }
  }

  private renderHint(width: number): string {
    return truncateToWidth(
      this.theme.hint("  ↑/↓ to navigate · Enter/Space to change · Esc to cancel"),
      width,
    );
  }
}
