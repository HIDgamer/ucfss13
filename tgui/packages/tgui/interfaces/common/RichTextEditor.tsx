import {
  forwardRef,
  type MouseEvent,
  useImperativeHandle,
  useRef,
} from 'react';

import { Box, Button, Divider, Dropdown, Stack } from '../../components';

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
};

const FIELD_HTML = '<span class="paper_field"></span>';
const SIGN_HTML = '<span class="paper_sign_placeholder"></span>';
const DATE_HTML = '<span class="paper_date_placeholder"></span>';

export const RichTextEditor = forwardRef<RichTextEditorHandle, Props>(
  (props, forwardedRef) => {
    const { mode, logos = [], presets = [], minHeight = '250px' } = props;
    const surfaceRef = useRef<HTMLDivElement>(null);

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

    return (
      <Stack vertical>
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
                          surfaceRef.current?.focus();
                          insertHtml(logo.html);
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
                          surfaceRef.current?.focus();
                          insertHtml(preset.html);
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
              style={{ outline: 'none', minHeight: '1.2em' }}
            />
          </Box>
        </Stack.Item>
      </Stack>
    );
  },
);
