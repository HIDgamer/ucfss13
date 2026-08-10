import { hexToHsva, HsvaColor, hsvaToHex } from 'common/color';
import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  ColorBox,
  DmIcon,
  Dropdown,
  Input,
  Modal,
  Section,
  Stack,
  Tooltip,
} from '../components';
import { Window } from '../layouts';
import { ColorSelector } from './ColorPickerModal';

type HairPickerData = {
  hair_icon: string;
  hair_styles: { name: string; icon: string }[];
  hair_style: string;
  hair_color: string;

  facial_hair_icon: string;
  facial_hair_styles: { name: string; icon: string }[];
  facial_hair_style: string;
  facial_hair_color: string;

  gradient_available: BooleanLike;
  gradient_styles: string[];
  gradient_style: string;
  gradient_color: string;
};

type Category = 'hair' | 'facial_hair' | 'gradient';

export const HairPicker = () => {
  const { act, data } = useBackend<HairPickerData>();

  const {
    hair_icon,
    hair_style,
    hair_styles,
    hair_color,
    facial_hair_icon,
    facial_hair_style,
    facial_hair_styles,
    facial_hair_color,
    gradient_available,
    gradient_style,
    gradient_styles,
    gradient_color,
  } = data;

  const hasFacialHair = facial_hair_styles.length > 1;

  const [category, setCategory] = useState<Category>('hair');
  const [colorPicker, setColorPicker] = useState<Category | false>(false);

  const activeCategory: Category =
    (category === 'facial_hair' && !hasFacialHair) ||
    (category === 'gradient' && !gradient_available)
      ? 'hair'
      : category;

  let defaultColor = '#000000';
  switch (colorPicker) {
    case 'hair':
      defaultColor = hair_color;
      break;
    case 'facial_hair':
      defaultColor = facial_hair_color;
      break;
    case 'gradient':
      defaultColor = gradient_color;
      break;
    default:
      break;
  }

  return (
    <Window width={560} height={440} theme={'crtlobby'}>
      <Window.Content className="HairPicker">
        {!!colorPicker && (
          <ColorPicker
            type={colorPicker}
            close={() => setColorPicker(false)}
            default_color={defaultColor}
          />
        )}
        <Stack fill>
          <Stack.Item width="140px">
            <Section title="Categories" fill>
              <Stack vertical>
                <Stack.Item>
                  <Button
                    fluid
                    icon="scissors"
                    selected={activeCategory === 'hair'}
                    onClick={() => setCategory('hair')}
                  >
                    Hair
                  </Button>
                </Stack.Item>
                {hasFacialHair && (
                  <Stack.Item>
                    <Button
                      fluid
                      icon="user-tie"
                      selected={activeCategory === 'facial_hair'}
                      onClick={() => setCategory('facial_hair')}
                    >
                      Facial Hair
                    </Button>
                  </Stack.Item>
                )}
                {!!gradient_available && (
                  <Stack.Item>
                    <Button
                      fluid
                      icon="paintbrush"
                      selected={activeCategory === 'gradient'}
                      onClick={() => setCategory('gradient')}
                    >
                      Gradient
                    </Button>
                  </Stack.Item>
                )}
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            {activeCategory === 'hair' && (
              <HairGrid
                title="Hair"
                icon={hair_icon}
                styles={hair_styles}
                active={hair_style}
                color={hair_color}
                setColor={() => setColorPicker('hair')}
                action={(obj) => act('hair', obj)}
              />
            )}
            {activeCategory === 'facial_hair' && (
              <HairGrid
                title="Facial Hair"
                icon={facial_hair_icon}
                styles={facial_hair_styles}
                active={facial_hair_style}
                color={facial_hair_color}
                setColor={() => setColorPicker('facial_hair')}
                action={(obj) => act('facial_hair', obj)}
              />
            )}
            {activeCategory === 'gradient' && (
              <Section
                title="Gradient"
                fill
                buttons={
                  <Button onClick={() => setColorPicker('gradient')}>
                    <ColorBox color={gradient_color} mr={1} />
                    Color
                  </Button>
                }
              >
                <Dropdown
                  options={gradient_styles}
                  selected={gradient_style}
                  onSelected={(selected) => act('gradient', { name: selected })}
                  over
                />
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const ColorPicker = (props: {
  readonly type: Category;
  readonly close: () => void;
  readonly default_color: string;
}) => {
  const { act } = useBackend();

  const { type, close, default_color } = props;

  const [currentColor, setCurrentColor] = useState<HsvaColor>(
    hexToHsva(default_color || '#000000'),
  );

  return (
    <Modal width="100%">
      <Box width="350px">
        <Stack vertical>
          <Stack.Item>
            <ColorSelector
              color={currentColor}
              setColor={setCurrentColor}
              defaultColor={default_color}
              onConfirm={() => {
                close();
                act(`${type}_color`, { color: hsvaToHex(currentColor) });
              }}
            />
          </Stack.Item>
        </Stack>
      </Box>
    </Modal>
  );
};

const HairGrid = (props: {
  readonly title: string;
  readonly icon: string;
  readonly active: string;
  readonly styles: { icon: string; name: string }[];
  readonly color: string;
  readonly setColor: () => void;
  readonly action: (_: object) => void;
}) => {
  const { title, icon, styles, active, color, setColor, action } = props;

  return (
    <HairPickerElement
      name={title}
      icon={icon}
      hair={styles}
      active={active}
      color={color}
      setColor={setColor}
      action={action}
      height="380px"
    />
  );
};

// Also used standalone (not inside HairPicker's category-sidebar layout) by PredPicker's
// "Quill Style" modal, which needs its own close button and a fixed height instead of filling
// a Stack.Item — kept as a separate exported component rather than folding into HairGrid above.
export const HairPickerElement = (props: {
  readonly name: string;
  readonly icon: string;
  readonly active: string;
  readonly hair: { icon: string; name: string }[];
  readonly color?: string;
  // An explicit height (not `fill`) — Section--fill.Section--scrollable makes its content
  // `position: absolute`, which breaks the drop-shadow color-tint trick below for tiles flush
  // against the top edge (found live: the whole first row rendered blank/offset). Explicit pixel
  // heights are also what LoadoutPicker.tsx/TraitsPicker.tsx already use for their scrollable
  // grid/list Sections — this matches that established, working pattern instead.
  readonly height?: number | string;

  readonly action: (_: object) => void;
  readonly setColor?: (_) => void;
  readonly close?: () => void;
}) => {
  const { name, icon, hair, active, action, setColor, close, color, height } = props;

  const [search, setSearch] = useState('');

  return (
    <Section
      title={name}
      height={height}
      scrollable
      buttons={
        <>
          <Input
            placeholder="Search..."
            onInput={(_, val) => setSearch(val.toLowerCase())}
            mr={1}
          />
          {color && (
            <Button onClick={() => (setColor ? setColor(action) : null)}>
              <ColorBox color={color} mr={1} />
              Color
            </Button>
          )}
          {close && <Button icon="xmark" onClick={() => close()} />}
        </>
      }
    >
      <Stack wrap="wrap">
        {hair
          .filter(
            (val) =>
              search.length === 0 || val.name.toLowerCase().includes(search),
          )
          .sort((a, b) => (a.name > b.name ? 1 : -1))
          .map((hair) => (
            <Stack.Item
              key={hair.name}
              className={`Picker${active === hair.icon ? ' Active' : ''}`}
            >
              <Tooltip content={hair.name}>
                <Box position="relative" onClick={() => action({ name: hair.name })}>
                  <DmIcon
                    icon={icon}
                    icon_state={`${hair.icon}_s`}
                    height="64px"
                    width="64px"
                    style={{ filter: `drop-shadow(0px 1000px 0 ${color})` }}
                  />
                </Box>
              </Tooltip>
            </Stack.Item>
          ))}
      </Stack>
    </Section>
  );
};
