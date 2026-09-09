import {
  forwardRef,
  type MouseEvent,
  useEffect,
  useImperativeHandle,
  useRef,
} from 'react';

import { Box, Button, Divider, Dropdown, Stack } from '../../components';

// Gives the otherwise-empty field/signature/date placeholder spans real, clickable presence -
// without this they're zero-width empty <span>s with no CSS anywhere, so a reopened paper has
// nothing visible to click into, and inserting a signature/date shows nothing until the paper is
// committed and the placeholder gets resolved into real text server-side. The ::before labels are
// pure CSS content - never part of innerHTML, so they never reach the server or get sanitized.
export const PAPER_FIELD_STYLES = `
  .paper_field, .paper_sign_placeholder, .paper_date_placeholder {
    display: inline-block;
    min-height: 1em;
    vertical-align: text-bottom;
    border-bottom: 1px dashed currentColor;
  }
  .paper_field {
    min-width: 4em;
  }
  .paper_sign_placeholder, .paper_date_placeholder {
    min-width: 6em;
    font-style: italic;
    opacity: 0.55;
  }
  .paper_sign_placeholder::before {
    content: 'Signature';
  }
  .paper_date_placeholder::before {
    content: 'Date';
  }
`;

export type RichTextEditorHandle = {
  getHtml: () => string;
  focus: () => void;
  clear: () => void;
};

export type Logo = {
  label: string;
  html: string;
};

export type Preset = {
  label: string;
  html: string;
};

type Props = {
  mode: 'pen' | 'crayon';
  logos?: Logo[];
  presets?: Preset[];
  minHeight?: string;
  /** Loaded into the surface once on mount - not re-applied on later prop changes, so it never
   * clobbers in-progress edits when the backend's data poll refreshes. */
  initialHtml?: string;
};

const FIELD_HTML = '<span class="paper_field"></span>';
const SIGN_HTML = '<span class="paper_sign_placeholder"></span>';
const DATE_HTML = '<span class="paper_date_placeholder"></span>';

// A fixed palette, not a free-form picker - every value here is a plain color name, which
// paper_sanitizer.dm's color_re already allow-lists (also accepts #RRGGBB hex, but a preset list
// keeps this simple and avoids needing any client-side hex validation).
const TEXT_COLORS = [
  { label: 'Black', value: 'black' },
  { label: 'Blue', value: 'blue' },
  { label: 'Red', value: 'red' },
  { label: 'Green', value: 'green' },
  { label: 'Purple', value: 'purple' },
];

export const RichTextEditor = forwardRef<RichTextEditorHandle, Props>(
  (props, forwardedRef) => {
    const {
      mode,
      logos = [],
      presets = [],
      minHeight = '250px',
      initialHtml,
    } = props;
    const surfaceRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
      if (surfaceRef.current && initialHtml) {
        surfaceRef.current.innerHTML = initialHtml;
      }
      // Chromium shows native drag handles on a selected image inside a contentEditable region
      // once this is on - this is what gives Google-Docs-style "drag a corner to resize" for
      // logos/images, with no custom drag/resize UI of our own to build or maintain.
      document.execCommand('enableObjectResizing', false, 'true');
      // Intentionally empty deps - load once on mount only, see the initialHtml prop doc above.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useImperativeHandle(forwardedRef, () => ({
      getHtml: () => surfaceRef.current?.innerHTML ?? '',
      focus: () => surfaceRef.current?.focus(),
      clear: () => {
        if (surfaceRef.current) {
          surfaceRef.current.innerHTML = '';
        }
      },
    }));

    const exec = (command: string, value?: string) => {
      surfaceRef.current?.focus();
      document.execCommand(command, false, value);
    };

    const insertHtml = (html: string) => {
      exec('insertHTML', html);
    };

    // onMouseDown + preventDefault keeps focus (and the live selection) inside the
    // contentEditable surface instead of the toolbar button stealing it before the
    // click's execCommand call can act on the selection.
    const toolbarButtonProps = {
      onMouseDown: (e: MouseEvent) => e.preventDefault(),
    };

    // Dropdown menus (unlike the buttons above) don't guard mousedown, so opening one and
    // clicking an option loses the surface's live selection before onSelected ever fires. We
    // track the last real selection ourselves and restore it right before inserting, instead of
    // relying on the browser to have kept it through the dropdown's own click handling.
    const savedRangeRef = useRef<Range | null>(null);

    const saveSelection = () => {
      const sel = window.getSelection();
      if (sel && sel.rangeCount > 0 && surfaceRef.current?.contains(sel.anchorNode)) {
        savedRangeRef.current = sel.getRangeAt(0).cloneRange();
      }
    };

    const insertHtmlAtSavedSelection = (html: string) => {
      surfaceRef.current?.focus();
      const sel = window.getSelection();
      const range = savedRangeRef.current;
      if (sel && range) {
        sel.removeAllRanges();
        sel.addRange(range);
      }
      document.execCommand('insertHTML', false, html);
    };

    // Not execCommand('foreColor', ...) - Chromium emits <span style="color:...">, which the
    // sanitizer's span-handling branch doesn't allow-list at all and would silently strip the
    // color entirely on commit. <font color="..."> is what paper_sanitizer.dm actually accepts
    // (it's also what whole-paper pen-color tinting already produces), so this wraps the saved
    // selection in one directly instead.
    const applyTextColorAtSavedSelection = (color: string) => {
      surfaceRef.current?.focus();
      const sel = window.getSelection();
      const range = savedRangeRef.current;
      if (!sel || !range || range.collapsed) {
        return;
      }
      sel.removeAllRanges();
      sel.addRange(range);
      const font = document.createElement('font');
      font.setAttribute('face', mode === 'crayon' ? 'Comic Sans MS' : 'Verdana');
      font.setAttribute('color', color);
      font.appendChild(range.extractContents());
      range.insertNode(font);
      sel.removeAllRanges();
      const after = document.createRange();
      after.setStartAfter(font);
      after.collapse(true);
      sel.addRange(after);
    };

    return (
      <Stack vertical>
        <style>{PAPER_FIELD_STYLES}</style>
        <Stack.Item>
          <Stack wrap>
            <Stack.Item>
              <Button
                icon="bold"
                tooltip="Bold"
                {...toolbarButtonProps}
                onClick={() => exec('bold')}
              />
            </Stack.Item>
            {mode === 'pen' && (
              <>
                <Stack.Item>
                  <Button
                    icon="italic"
                    tooltip="Italic"
                    {...toolbarButtonProps}
                    onClick={() => exec('italic')}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="underline"
                    tooltip="Underline"
                    {...toolbarButtonProps}
                    onClick={() => exec('underline')}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Heading 1"
                    {...toolbarButtonProps}
                    onClick={() => exec('formatBlock', '<h1>')}
                  >
                    H1
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Heading 2"
                    {...toolbarButtonProps}
                    onClick={() => exec('formatBlock', '<h2>')}
                  >
                    H2
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Heading 3"
                    {...toolbarButtonProps}
                    onClick={() => exec('formatBlock', '<h3>')}
                  >
                    H3
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Small text (select text first)"
                    {...toolbarButtonProps}
                    onClick={() => exec('fontSize', '1')}
                  >
                    S
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Normal text (select text first)"
                    {...toolbarButtonProps}
                    onClick={() => exec('fontSize', '3')}
                  >
                    N
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Large text (select text first)"
                    {...toolbarButtonProps}
                    onClick={() => exec('fontSize', '4')}
                  >
                    L
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    tooltip="Huge text (select text first)"
                    {...toolbarButtonProps}
                    onClick={() => exec('fontSize', '6')}
                  >
                    H
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="align-center"
                    tooltip="Center"
                    {...toolbarButtonProps}
                    onClick={() => exec('justifyCenter')}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="list-ul"
                    tooltip="Bullet List"
                    {...toolbarButtonProps}
                    onClick={() => exec('insertUnorderedList')}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="grip-lines"
                    tooltip="Horizontal Rule"
                    {...toolbarButtonProps}
                    onClick={() => exec('insertHorizontalRule')}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="square"
                    tooltip="Insert Field"
                    {...toolbarButtonProps}
                    onClick={() => insertHtml(FIELD_HTML)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="signature"
                    tooltip="Insert Signature"
                    {...toolbarButtonProps}
                    onClick={() => insertHtml(SIGN_HTML)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="calendar"
                    tooltip="Insert Date"
                    {...toolbarButtonProps}
                    onClick={() => insertHtml(DATE_HTML)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Dropdown
                    icon="palette"
                    displayText="Text Color"
                    tooltip="Select text first, then pick a color"
                    selected={null}
                    options={TEXT_COLORS.map((c) => c.label)}
                    onSelected={(label) => {
                      const color = TEXT_COLORS.find((c) => c.label === label);
                      if (color) {
                        applyTextColorAtSavedSelection(color.value);
                      }
                    }}
                  />
                </Stack.Item>
                {logos.length > 0 && (
                  <Stack.Item>
                    <Dropdown
                      icon="image"
                      displayText="Insert Logo"
                      selected={null}
                      options={logos.map((logo) => logo.label)}
                      onSelected={(label) => {
                        const logo = logos.find((l) => l.label === label);
                        if (logo) {
                          insertHtmlAtSavedSelection(logo.html);
                        }
                      }}
                    />
                  </Stack.Item>
                )}
                {presets.length > 0 && (
                  <Stack.Item>
                    <Dropdown
                      icon="file-lines"
                      displayText="Insert Template"
                      selected={null}
                      options={presets.map((preset) => preset.label)}
                      onSelected={(label) => {
                        const preset = presets.find((p) => p.label === label);
                        if (preset) {
                          insertHtmlAtSavedSelection(preset.html);
                        }
                      }}
                    />
                  </Stack.Item>
                )}
              </>
            )}
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Divider />
        </Stack.Item>
        <Stack.Item>
          <Box
            className="paper"
            backgroundColor="white"
            color="black"
            p="0.75rem"
            style={{
              minHeight: minHeight,
              maxHeight: '400px',
              overflowY: 'auto',
              fontFamily: mode === 'crayon' ? 'Comic Sans MS' : 'Verdana',
            }}
          >
            {/* Uncontrolled by design - React never re-renders this node's children, so
                typing and execCommand mutate the live DOM directly without the cursor
                jumping on every keystroke. */}
            <div
              ref={surfaceRef}
              contentEditable
              suppressContentEditableWarning
              onMouseUp={saveSelection}
              onKeyUp={saveSelection}
              style={{ outline: 'none', minHeight: '1.2em' }}
            />
          </Box>
        </Stack.Item>
      </Stack>
    );
  },
);
