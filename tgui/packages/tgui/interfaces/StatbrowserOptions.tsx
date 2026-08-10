import { ReactNode, useState } from 'react';

import { useBackend } from '../backend';
import { Flex, NumberInput, Section } from '../components';
import { Window } from '../layouts';

type Data = {
  current_fontsize: number;
};

export const StatbrowserOptions = () => {
  const { act, data } = useBackend<Data>();
  const { current_fontsize } = data;
  const [fontsize, setFontsize] = useState(current_fontsize);

  return (
    <Window title="Statbrowser Options" width={300} height={120}>
      <Window.Content>
        <Options>
          <NumberOption
            category="Font Size"
            value={fontsize}
            minValue={10}
            maxValue={30}
            step={0.5}
            format={(value) => value + 'px'}
            onChange={(value) => {
              setFontsize(value);
              act('change_fontsize', { new_fontsize: value });
            }}
          />
        </Options>
      </Window.Content>
    </Window>
  );
};

const Options = (props: { readonly children: ReactNode }) => {
  const { children } = props;

  return (
    <Section title="Options">
      <Flex spacing={16 * 2}>
        {!Array.isArray(children)
          ? children
          : children.map((option, i) => (
              <Flex.Item key={i}>{option}</Flex.Item>
            ))}
      </Flex>
    </Section>
  );
};

const Option = (props: { readonly category: ReactNode; readonly input: ReactNode }) => {
  const { category, input } = props;

  return (
    <Flex>
      <Flex.Item mr="5px">{category}</Flex.Item>
      <Flex.Item>{input}</Flex.Item>
    </Flex>
  );
};

type NumberOptionProps = {
  readonly category: ReactNode;
  readonly value: number;
  readonly minValue: number;
  readonly maxValue: number;
  readonly step: number;
  readonly format: (value: number) => string;
  readonly onChange: (value: number) => void;
};

const NumberOption = (props: NumberOptionProps) => {
  const { category, ...rest } = props;

  return <Option category={category} input={<NumberInput {...rest} />} />;
};
