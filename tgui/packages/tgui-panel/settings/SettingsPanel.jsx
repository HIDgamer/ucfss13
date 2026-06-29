/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { toFixed } from 'common/math';
import { useState } from 'react';
import { useDispatch, useSelector } from 'tgui/backend';
import {
  Box,
  Button,
  ColorBox,
  Divider,
  Dropdown,
  Input,
  LabeledList,
  NumberInput,
  Section,
  Stack,
  Tabs,
  TextArea,
  Tooltip,
} from 'tgui/components';

import { ChatPageSettings } from '../chat';
import { clearChat, rebuildChat, saveChatToDisk } from '../chat/actions';
import { CRT_THEMES } from '../themes';
import {
  addHighlightSetting,
  changeSettingsTab,
  removeHighlightSetting,
  updateHighlightSetting,
  updateSettings,
} from './actions';
import { FONTS, MAX_HIGHLIGHT_SETTINGS, SETTINGS_TABS } from './constants';
import {
  selectActiveTab,
  selectHighlightSettingById,
  selectHighlightSettings,
  selectSettings,
} from './selectors';

export const SettingsPanel = (props) => {
  const activeTab = useSelector(selectActiveTab);
  const dispatch = useDispatch();
  return (
    <Stack fill>
      <Stack.Item>
        <Section fitted fill minHeight="8em">
          <Tabs vertical>
            {SETTINGS_TABS.map((tab) => (
              <Tabs.Tab
                key={tab.id}
                selected={tab.id === activeTab}
                onClick={() =>
                  dispatch(
                    changeSettingsTab({
                      tabId: tab.id,
                    }),
                  )
                }
              >
                {tab.name}
              </Tabs.Tab>
            ))}
          </Tabs>
        </Section>
      </Stack.Item>
      <Stack.Item grow={1} basis={0}>
        {activeTab === 'general' && <SettingsGeneral />}
        {activeTab === 'chatPage' && <ChatPageSettings />}
        {activeTab === 'textHighlight' && <TextHighlightSettings />}
      </Stack.Item>
    </Stack>
  );
};

const ThemeSwatch = ({ name, config, selected, onSelect }) => (
  <Tooltip content={config ? config.label : name}>
    <Box
      inline
      mr={0.5}
      mb={0.5}
      style={{
        cursor: 'pointer',
        width: '1.6em',
        height: '1.6em',
        backgroundColor: config
          ? config.bg
          : name === 'dark'
            ? '#202020'
            : '#e8e8e8',
        border: selected
          ? `2px solid ${config ? config.fg : name === 'dark' ? '#a4bad6' : '#333'}`
          : '2px solid transparent',
        outline: selected ? '1px solid rgba(255,255,255,0.3)' : 'none',
        boxSizing: 'border-box',
        position: 'relative',
      }}
      onClick={() => onSelect(name)}
    >
      {config && (
        <Box
          style={{
            position: 'absolute',
            bottom: '2px',
            right: '2px',
            width: '6px',
            height: '6px',
            backgroundColor: config.fg,
            borderRadius: '50%',
          }}
        />
      )}
    </Box>
  </Tooltip>
);

export const SettingsGeneral = (props) => {
  const { theme, colorPreset, fontFamily, fontSize, lineHeight } =
    useSelector(selectSettings);
  const dispatch = useDispatch();
  const [freeFont, setFreeFont] = useState(false);

  const selectBase = (value) => dispatch(updateSettings({ theme: value }));
  const selectPreset = (value) =>
    dispatch(updateSettings({ colorPreset: value === 'none' ? null : value }));

  return (
    <Section>
      <LabeledList>
        <LabeledList.Item label="Theme">
          <Stack vertical>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item>
                  <ThemeSwatch
                    name="dark"
                    config={null}
                    selected={theme === 'dark'}
                    onSelect={selectBase}
                  />
                  <ThemeSwatch
                    name="light"
                    config={null}
                    selected={theme === 'light'}
                    onSelect={selectBase}
                  />
                </Stack.Item>
                <Stack.Item color="label" fontSize="0.85em">
                  Base ({theme === 'light' ? 'Light' : 'Dark'})
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item>
                  <ThemeSwatch
                    name="none"
                    config={null}
                    selected={!colorPreset}
                    onSelect={() => selectPreset('none')}
                  />
                  {Object.entries(CRT_THEMES).map(([key, cfg]) => (
                    <ThemeSwatch
                      key={key}
                      name={key}
                      config={cfg}
                      selected={colorPreset === key}
                      onSelect={selectPreset}
                    />
                  ))}
                </Stack.Item>
                <Stack.Item color="label" fontSize="0.85em">
                  CRT ({colorPreset ? CRT_THEMES[colorPreset]?.label : 'None'})
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </LabeledList.Item>
        <LabeledList.Item label="Font style">
          <Stack inline align="center">
            <Stack.Item>
              {(!freeFont && (
                <Dropdown
                  selected={fontFamily}
                  options={FONTS}
                  onSelected={(value) =>
                    dispatch(
                      updateSettings({
                        fontFamily: value,
                      }),
                    )
                  }
                />
              )) || (
                <Input
                  width="15em"
                  value={fontFamily}
                  onChange={(e, value) =>
                    dispatch(
                      updateSettings({
                        fontFamily: value,
                      }),
                    )
                  }
                />
              )}
            </Stack.Item>
            <Stack.Item>
              <Button
                ml={0.5}
                icon={freeFont ? 'lock-open' : 'lock'}
                color={freeFont ? 'good' : 'bad'}
                onClick={() => {
                  setFreeFont(!freeFont);
                }}
              >
                Custom font
              </Button>
            </Stack.Item>
          </Stack>
        </LabeledList.Item>
        <LabeledList.Item label="Font size">
          <NumberInput
            width="4.2em"
            step={1}
            stepPixelSize={10}
            minValue={8}
            maxValue={48}
            value={fontSize}
            unit="px"
            format={(value) => toFixed(value)}
            onChange={(value) =>
              dispatch(
                updateSettings({
                  fontSize: value,
                }),
              )
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Line height">
          <NumberInput
            width="4.2em"
            step={0.01}
            stepPixelSize={2}
            minValue={0.8}
            maxValue={5}
            value={lineHeight}
            format={(value) => toFixed(value, 2)}
            onDrag={(value) =>
              dispatch(
                updateSettings({
                  lineHeight: value,
                }),
              )
            }
          />
        </LabeledList.Item>
      </LabeledList>
      <Divider />
      <Stack fill>
        <Stack.Item grow mt={0.15}>
          <Button
            icon="save"
            tooltip="Export current tab history into HTML file"
            onClick={() => dispatch(saveChatToDisk())}
          >
            Save chat log
          </Button>
        </Stack.Item>
        <Stack.Item mt={0.15}>
          <Button.Confirm
            icon="trash"
            tooltip="Erase current tab history"
            onClick={() => dispatch(clearChat())}
          >
            Clear chat
          </Button.Confirm>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const TextHighlightSettings = (props) => {
  const highlightSettings = useSelector(selectHighlightSettings);
  const dispatch = useDispatch();
  return (
    <Section fill scrollable height="250px">
      <Stack vertical>
        {highlightSettings.map((id, i) => (
          <TextHighlightSetting
            key={i}
            id={id}
            mb={i + 1 === highlightSettings.length ? 0 : '10px'}
          />
        ))}
        {highlightSettings.length < MAX_HIGHLIGHT_SETTINGS && (
          <Stack.Item>
            <Button
              color="transparent"
              icon="plus"
              onClick={() => {
                dispatch(addHighlightSetting());
              }}
            >
              Add Highlight Setting
            </Button>
          </Stack.Item>
        )}
      </Stack>
      <Divider />
      <Box>
        <Button icon="check" onClick={() => dispatch(rebuildChat())}>
          Apply now
        </Button>
        <Box inline fontSize="0.9em" ml={1} color="label">
          Can freeze the chat for a while.
        </Box>
      </Box>
    </Section>
  );
};

const TextHighlightSetting = (props) => {
  const { id, ...rest } = props;
  const highlightSettingById = useSelector(selectHighlightSettingById);
  const dispatch = useDispatch();
  const {
    highlightColor,
    highlightText,
    highlightWholeMessage,
    matchWord,
    matchCase,
  } = highlightSettingById[id];
  return (
    <Stack.Item {...rest}>
      <Stack mb={1} color="label" align="baseline">
        <Stack.Item grow>
          <Button
            color="transparent"
            icon="times"
            onClick={() =>
              dispatch(
                removeHighlightSetting({
                  id: id,
                }),
              )
            }
          >
            Delete
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={highlightWholeMessage}
            tooltip="If this option is selected, the entire message will be highlighted in yellow."
            onClick={() =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  highlightWholeMessage: !highlightWholeMessage,
                }),
              )
            }
          >
            Whole Message
          </Button.Checkbox>
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={matchWord}
            tooltipPosition="bottom-start"
            tooltip="If this option is selected, only exact matches (no extra letters before or after) will trigger. Not compatible with punctuation. Overriden if regex is used."
            onClick={() =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  matchWord: !matchWord,
                }),
              )
            }
          >
            Exact
          </Button.Checkbox>
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            tooltip="If this option is selected, the highlight will be case-sensitive."
            checked={matchCase}
            onClick={() =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  matchCase: !matchCase,
                }),
              )
            }
          >
            Case
          </Button.Checkbox>
        </Stack.Item>
        <Stack.Item>
          <ColorBox mr={1} color={highlightColor} />
          <Input
            width="5em"
            monospace
            placeholder="#ffffff"
            value={highlightColor}
            onInput={(e, value) =>
              dispatch(
                updateHighlightSetting({
                  id: id,
                  highlightColor: value,
                }),
              )
            }
          />
        </Stack.Item>
      </Stack>
      <TextArea
        height="3em"
        value={highlightText}
        placeholder="Put words to highlight here. Separate terms with commas, i.e. (term1, term2, term3)"
        onChange={(e, value) =>
          dispatch(
            updateHighlightSetting({
              id: id,
              highlightText: value,
            }),
          )
        }
      />
    </Stack.Item>
  );
};
