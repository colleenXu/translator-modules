# TranslatorCWL

Get started immediately by **[using TranslatorCWL](#using-translatorcwl).**

For the justification of this project, find out **[how TranslatorCWL works](#how-translatorcwl-works).**

An introduction to Common Workflow Language can be found on the **[CWL website](commonwl.org).**


# Using TranslatorCWL

## Quickstart

Follow the instructions for [putting Translator Modules on the system path](#placing-modules-on-the-path). Then in 
the project directory, run

```bash
pip install cwltool
cwltool biocwl/workflows/wf2.cwl biocwl/data/inputs/fanconi.yaml
```
If you can run `wf2.cwl` with `fanconi.yaml` successfully,
* You have just run a CWL tool.
* You have just used multiple modules chained together at once.
* You have replicated the [Fanconi Anaemia Tidbit]().

#### TODO Docker instructions
Otherwise, if you've set up [Docker](), then we can do

```bash

```

## Placing modules on the path

In order to use the CWL tools in `biocwl/workflows/`, one must put the modules from `translator_modules/modules<*>/` on the system path.

This lets your CWL Runner use these modules by identifying them on the absolute path, and lets the codebase be portable across systems
if you are not using a virtual machine.

One way to do this (not recommended) is by adding `translator_modules` onto the system path directly:

```bash
export PATH=$PATH$( find $LOCATION/$OF/$PROJECT/translator-modules/translator_modules/ -type d -printf ":%p" )
```

By default, each translator module should have `#!/usr/bin/python3` as their specified interpreter, written at the top of the file.

Additionally, ensure that each module is kept executable by performing `chomd a+x *` within `translator_modules`.

Finally, if you are developing on Windows, ensure that you are enforcing Unix-style newlines in these files.
You can do this using a tool like `dos2unix`, or by running the Vim command `set: fileformat=unix` on the file.

Our CWL specs can now be kept terse, as they don't require an absolute path to access them nor a python call to run them, like so.

```cwl
#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ module0.py, get-data-frame, to-json ]
```

## Running a CWL tool

CWL tools are not scripts, but blueprints for running scripts. They let users clarify beforehand the kinds of data they 
should expected for a script: names for the data, their types and formats, and what arguments they satisfy. Let's take a simple example:

```
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ module0.py, get-data-frame, to-json, --orient, records ]
inputs:
  disease_name:
    type: string
    inputBinding:
      prefix: --input-disease-name
  disease_id:
    type: string
    inputBinding:
      prefix: --input-disease-mondo
outputs:
  disease_list:
    type: stdout
stdout: module0.records.json
```

This is `biocwl/workflows/module0.cwl` wrapping `translator_modules/module0.py`. All CWL tools for Translator Modules share this
structure. We will run `module0.py` with inputs given by `disease_name` and `disease_id`, corresponding to the flags 
`--input-disease-name`, and `--input-disease-mondo`, which are the names of variables inside the module. 
The tokens `get-data-frame to-json --orient records` make `module0.py` return a list of JSON records; see 
[exposing your module to the command line](#exposing-your-module-to-the-command-line) for details.

If CWL is a blueprint, what makes it real? Inputs to CWL tools are YAML files that share the same keywords as the tool's
inputs. For `module0.cwl`, this means we want a YAML file with `disease_name` and `diease_id`, like in `biocwl/data/inputs/fanconi.yaml`:

```bash
disease_name: "FA"
disease_id: "MONDO:0019391"
```

**Running a CWL tool uses the following command:**
```bash
cwltool <translator cwl tool> <file with keywords matching the tool's inputs>
```

And taken together, it means that this UNIX command:

```bash
module0.py --inputs-disease-name "FA" --input-disease-mondo "MONDO:0019391" get-data-frame to-json --orient records
```

Is *equivalent to* **this CWL tool running Translator Module 0:**

```bash
cwltool biocwl/workflows/module0.cwl biocwl/data/inputs/fanconi.yaml
```

## Writing a CWL tool for an existing module

To make the magic happen, there are a few standard practices needed to obeyed by developers seeking to turn a Translator
Module, into a TranslatorCWL tool. **Note:** This section is undergoing changes while an optimal approach is sought for developing workflow modules.

### Exposing your module to the command line

The NCATS ecosystem contains a diverse array of APIs and resources, which means that sometimes information which is
conceptually similar, might only be accessible in irregular ways, or come in heterogenuous formats.

As such, the way we get information ought to be decoupled from the way we view information. Consumers shouldn't have to solve these problems: they should ask for information in the simplest way possible, and find it 
easy to transform data however they like.

Our answer to this requirement is to ask modules to use a class called `Payload` to help turn the module into a command line tool.
This involves the following:

* Extend the `Payload` class with a constructor that takes workflow parameters (e.g. `disease_id`, `gene_set`, `threshold_score`...) as its arguments;
* Finding a way to expose these arguments to the command line (such as with [Python Fire]());
* Transform the module's results into a [Pandas DataFrame]();
* Use `Payload`'s accessor methods to return output in TranslatorCWL tools.

#### TODO: Finish Payload Refactoring
#### TODO: Use a representative class like Module1a?

Here is an example of a class with these modifications made: `Module1a.py`

```python


```

Likewise, if exposing your own module to the command line, you need to guarantee that it's on the path and executable ([see here](#placing-modules-on-the-path)).

After you've ensured that your module is executable, add the following to the bottom of its script:

```python
from translator_modules.core import Payload
import fire
import pandas as pd

class <ModuleOutputName>(Payload):
    def __init__(self, workflow, args, go, here):
        super(<ModuleOutputName>, self).__init__(<ModuleClassName>())
        self.result = _<result_procedure>(workflow, args, go, here)
        
    def _<result_procedure>(self, workflow, args, go, here) -> pd.DataFrame:
        delegated_results = self.mod.<results_giving_function>()
        pandas_dataframe_results = pd.DataFrame(delegated_results)
        return pandas_dataframe_results

if __name__ == '__main__':
    fire.Fire(<ModuleOutputName>)
```

The code above will obviously not interpret correctly. Instead, it illustrates the general strategy for exposing modules. The
module itself is passed as a fully instantiated Python object to `Payload`'s constructor via `super().__init__(module)`, 
which lets you use its methods as a delegated way of getting the module's results (in a function like `compute_similarity` or `results_giving_function` here). The point of doing it this way is that you are meant to convert whatever 
the module outputs into a DataFrame, and put it in a place usable by `Payload`'s accessors.

The names within the triangular brackets `< >` don't matter except by the content they describe. Just remember that ModuleClassName
means the class of the module this code is pasted in, and ModuleOutputName means actual biological content being returned by the module.

`_<result_procedure>` is private because it only should ever be run as many times as the entire object is called during the workflow,
else the object is not behaving like a function or command. So there's no need to expose it to the user.

#### Why output JSON?

JSON is a lingua franca format on the web, you can represent objects with it (including Biolink objects), it's the format 
that many schema standards like OWL and JSON-LD expect to be handling other than YAML or XML. CSV is preferable for researchers though. Some thinking on how to go from JSON to tables in a nice way will need to be done.

#### Why use Pandas DataFrames inside scripts?

DataFrames are powerful objects that can be built from several formats, and output several formats. As such it is 
adequate to represent information in DataFrames when you have many serialization formats within the ecosystem that need 
to be handled regularly. They will also be flexible enough to handle our changing understanding of what formats are needed for 
SMEs and application developers.

#### Why Python Fire?

Fire makes it simple to expose any Python class to the command-line, in only **three lines of code**. This means it is easy for
maintainers to add command-line functionality to modules, and it's easy to delete Fire if we change our minds about the approach.

It does have limitations: complex arguments (like mutually exclusive yet simultaneously required arguments) are not supported.
And you can't pipe commands with it, although you can compose the functions of a single module easily.

An argument can be made for moving to `argsparse` instead, or even eliminating the need to expose modules in this way, as
 the CWL ecosystem does support tool generation from Python files under various conditions.

### Creating the CWL tool file

Going through the [Common Workflow Language tutorial](), we often end up with files that look like this:

```cwl
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ myModule.py, get-data-frame, to-json, --orient, records ]
inputs:
  disease_name:
    type: string
    inputBinding:
      prefix: --input-disease-name
outputs:
  my_module_output:
    type: stdout
stdout: myModule.records.json
```

As your module should be on the path by now, we can put it inside of `baseCommand` given that this CWL tool has `CommandLineTool` 
as its `class`.

Using Python Fire or equivalent, you should be exposing the object extending the `Payload` class in your module's 
script, rather than the module class itself. Thus we can use `get-data-frame to-json --orient records` to call out the results of 
your module as a list of JSON records.

The `type` for given `inputs` correspond to JavaScript types. For Python, `float`, `int`, and `string` have common-sense 
equivalents. A list in Python becomes an `array` here, and a dict in Python becomes a `record`. You *can* have complex types, 
constructed by nesting `type: <datatype>` pairs in the YAML entry. There are also `File` types, referring to complex or custom 
types and their `formats`. None are used by the project thusfar.

There doesn't have to be a correlation between the names under `inputs` and the `prefixes`, but the `prefixes` have to match
the names of your `Payload` object's arguments in its constructor. Likewise, the names under `outputs` do not matter, but for
`stdout` the file name ought to be consistent with the format given by the `baseCommand`. 

**Note:** this might change in future iterations.

### Testing the tool

Just run it:

```cwl
cwltool <your cwl file> <your data file>
```

## Combining multiple CWL tools

`m0_m1.cwl` in `biocwl/workflows` is a simple canonical example of combining multiple CWL tools (taking a subset of `wf2.cwl`):

```cwl
cwlVersion: v1.0
class: Workflow
inputs:
    disease_name: string
    disease_id: string
    threshold_functional:
      type: float
      default: 0.75
outputs:
  functionally_similar_genes:
    type: File
    outputSource: functional_similarity/functionally_similar_genes
steps:
  diseases:
    run: module0.cwl
    in:
      disease_name: disease_name
      disease_id: disease_id
    out: [ disease_list ]

  functional_similarity:
    run: module1a.cwl
    in:
      gene_set: diseases/disease_list
      threshold: threshold_functional
    out: [ functionally_similar_genes ]
```

It is like creating a large CWL tool out of smaller ones. Like in a simple CWL tool, you need `inputs` and `outputs` to 
be specified. Multiple tools are used together by linking the outputs of one tool, into the inputs of another.

For instance, the tool `diseases` runs `module0.cwl`, that outputs a `disease_list`, which we address specifically in the 
property `out`.  We place `disease_list` into `functional_similarity`'s inputs by referencing what it is and where it came 
from, `diseases/disease_list`, and placing it as the value of the relevant input, `gene_set`.

A similar process is performed with the final results of `m0_m1.cwl`, where the output of `module1a.cwl` is connected to
former's outputs, by writing `outputSource: functional_similarity/functionally_similar_genes`.

Sometimes, your inputs cross-cut among many tools: it might be useful to set a `default` value like we did
with `threshold_functional`, so we don't have to put so many arguments into our input file, or re-use the input file of 
an existing script. So this:

```cwl
disease_name: "FA"
disease_id: "MONDO:0019391"
```

Or this:

```cwl
disease_name: "FA"
disease_id: "MONDO:0019391"
threshold_functional: 0.35
```

... are both valid input files.

Note that the order in which modules are run, depends solely on when one tool has finished computing the required data 
for another. Thus `module1a.cwl` runs after `module0.cwl` because of `diseases/disease_list` being referenced as an input.

Also note that there can be multiple outputs: you don't need to generally receive the results of one script, but can list
out the results of each script if necessary.

# How TranslatorCWL Works

## What's the point?

Each Translator Module acts as your data source for biomedical concepts from NCATS. Getting lists of genes is as simple 
as downloading the module from PyPI, and importing it into a Python script or Jupyter notebook for immediate use.

However, these Python scripts can be "brittle" or "inconsistent": these modules rely on the rest of the script to handle their 
results in a way that can be re-used by other modules, and NCATS gives no guarantee of this. Notebooks - excellent tools 
for finding and explaining results - do not compose into larger systems, which makes these results difficult to build upon.

This is the problem that TranslatorCWL hopes to improve.

### Chaining

*Tested*

Sometimes you don't need to use just one module: you need several. However, to string modules together requires a guarantee
that each module's outputs can be transformed to the formats required for the next module's inputs.

### Recombination

*Tested*

Additionally, sometimes you only need some modules, or the number of modules you are using changes. If there is a single Python script that used
all the modules, you would need to either comment them all out then comment them back in, or add feature flags to manage their execution.

This is cumbersome. With the approach in TranslatorCWL, files are much smaller and chaining modules is simpler, so it is at least
less cumbersome to construct workflows of different orders and sizes.

### Parralelism

*Untested*

This same properties that let modules be combined in any order, also let you run them in parralel (to "scatter" them).

Since certain modules tend to feature long-running queries, one ought to be able to let modules that can provide data independently, run separately, to save time.
Where it would be a headache to do implement this in a Python script, you can tell the CWL tool to do it just by adding a couple of lines of text to its spec.

### Portability

*Untested*

CWL's capacity to run in Docker environments eliminates the need to worry about system compatibility when it comes to running
workflows, and should be able to streamline the ability to run Translator Modules across platforms, if you're a user instead 
of a developer.

### Validation

*Untested*

The final benefit is that CWL can integrate with the BiolinkML standard remotely. By ensuring the Biolink Model is used throughout, you can have 
confidence that the data you're getting will be usable by other tools in NCATS, and refer to concepts in your domain of expertise.

## How do I use it? How do I write a new CWL tool?

See [Using TranslatorCWL](#using-translatorcwl).

## Is this *the* Common Workflow Language?

TranslatorCWL acts as the next logical step towards a "common language" for NCATS Translator. With a couple exceptions 
(given below), it encodes the same properties as the [configuration shown in this presentation](https://docs.google.com/presentation/d/19ieHAN-6DLvfRUR0WqCokiJTTfuA6TPL9GHbf5UENUs/edit#slide=id.g4201216ac9_0_38). 
In principle you can do anything a bash script would do, but now you can set it up with less mental hassle, run it with 
less worry about whether it will work on your computer, get Biolink data, and share your solution with others remotely 
either as a script or as its own data-source.

Nonetheless, it has certain drawbacks. 

### Could the interface be simpler?

CWL buys us [the advantages mentioned above](#whats-the-point). But it still requires [some boilerplate](#exposing-your-module-to-the-command-line) to set up, in the form of module wrappers, input files, and specs for the tools themselves. 
This boilerplate still features concepts and terminology which are more relevant to a developer or bioinformatician, than a "subject matter expert" (SME).

In an ideal situation, assuming that SMEs know the *kind* of information they seek, they should write queries in terms of biological entities rather than workflow chains. 
Ensuring the terms used in CWL workflows conform to the Biolink Model helps, but more work may be required to achieve the simplicity of, say, GraphQL syntax. 

Could we have something as simple as:

```graphql
{
    expand { 
      similarity(level: phenotype, threshold: 0.75) {
        disease(name: "FA") -> gene {
            id
        }
    }
}
```

On the other hand, the CWL ecosystem has tools like [Rabix](https://github.com/rabix/composer) that eliminate
text via their GUI, which would be a win for SMEs as long as developers take care of the tooling.

### Are these tools expanders and sharpeners?

It's currently implicit whether or not a module counts as a sharpener, expander, or set-theoretic operation. Therefore we 
would still rely on developers to obey a convention somewhere to make sure that expanders are actually expanders, sharpeners
are sharpeners, and everyone knows this, including perhaps the workflow and its users.

Options to treat these operations as concepts that can be validated, need to be explored.

### Do workflows correspond to the Biolink Model?

#### TODO check this against orange team biolink experts
In theory: any mapping from one concept to another, if not mediated by any other mapping, ought to be a `slot` within the 
Biolink model. Thus each module, if not each workflow, ought to correspond to a slot or a set of slots.

The correspondence seems to break with meta-data. For example, although the addition of scores to slots like `blw:macromolecular machine 
to biological process association` seems natural, `score` is (currently?) not a coordinate for a slot. As such, `score` is only a property of the 
slot *given the module computing it*, rather than its meaning being determined by the slot itself. It therefore depends on the module's
developers to ensure their interpretation of `score` is consistent with everyone else's.

This issue is not necessarily one to be handled by TranslatorCWL - it's a question of what role we want the ontology to 
play in the project. Even if we want all data to be closed under Biolink types, CWL could only enforce what's already in 
a given schema. It would be up to the modules to do adequate conversions.

In lieu of this, we rely on developer convention to give proper names to the inputs and outputs of CWL scripts, which
we shouldn't necessarily hinder in the case where the Biolink Model can't close over the computations *in principle*, but 
should attempt to bolster with the validator *whenever possible* to prevent inevitable mistakes and stop the Tower of Babel 
from bifurcating further.

## TODO
* Refactor `Payload` in `Module1a`, `Module1b` properly
* Rename `Payload` to something better
* Find better nomenclature for modules than "module< number >"
  * Can it be related to their biological content in some way? Lets us anticipate the kinds of modules ahead of time
  * Do all modules adhere to [the standard](https://docs.google.com/presentation/d/19ieHAN-6DLvfRUR0WqCokiJTTfuA6TPL9GHbf5UENUs/edit)?
* Create CWL types corresponding to NCATS domain
* Use BiolinkML types inside of `*.cwl` specs
* Replace current path strategy with use of GNU `stow`
* Revise input/outputs formats of BioCWL tools with Biolink Types
* Enforce types with formats in CWL spec
* Move away from Python Fire to leverage other CWL tools that can autogenerate workflows
* Is the approach of using intermediary files the correct one?