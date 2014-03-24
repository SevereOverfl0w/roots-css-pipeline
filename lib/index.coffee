node      = require 'when/node'
fs        = require 'fs'
path      = require 'path'
_         = require 'lodash'
minimatch = require 'minimatch'
glob      = require 'glob'
File      = require 'vinyl'
mkdirp    = require 'mkdirp'
CleanCSS  = require 'clean-css'
# RootsUtil  = require 'roots-util'

module.exports = (opts) ->

  opts = _.defaults opts,
    files: 'assets/css/**'
    out: false
    minify: false
    opts: {}

  class CSSPipeline

    ###*
     * Sets up the custom category and view function.
     * The view function grabs either the single output path or collects
     * all non-ignored output paths for the input files and returns them
     * as html link tags.
     * 
     * @param  {Function} @roots - Roots class instance
    ###

    constructor: (@roots) ->
      @category = 'css-pipeline'
      @contents = ''
      # @util = new RootsUtil(@roots)

      @roots.config.locals ?= {}
      @roots.config.locals.css = =>
        paths = []

        if opts.out
          paths.push(opts.out)
        else
          # grab all the files
          files = glob.sync(path.join(@roots.root, opts.files))
          # reject directories
          files = _.reject(files, (f) -> fs.statSync(f).isDirectory())
          # reject any ignored files
          files = _.reject files, (f) =>
            _.any(@roots.config.ignores, (i) -> minimatch(f, i, { dot: true }))
          # map to roots output path, then remove base path
          files = files.map (f) =>
            @roots.config
              .out(new File(base: @roots.root, path: f), 'css')
              .replace(@roots.config.output_path(), '')

          # concat resuling array to paths
          paths = paths.concat(files)
        
        paths.map((p) -> "<link rel='stylesheet' src='#{p}' />").join("\n")

    ###*
     * Minimatch runs against each path, quick and easy.
    ###

    fs: ->
      extract: true
      detect: (f) -> minimatch(f.relative, opts.files)

    ###*
     * After compile, if concat is happening, grab the contents and save them
     * away, then prevent write.
    ###

    compile_hooks: ->
      after_file: (ctx) => if opts.out then @contents += ctx.content
      write: -> !opts.out

    ###*
     * Write the output file if necessary.
    ###

    category_hooks: ->
      after: (ctx) =>
        # if opts.out then @util.write(opts.out, @contents)
        if not opts.out then return

        if opts.minify then @contents = (new CleanCSS(opts.opts)).minify(@contents)

        output_path = path.join(ctx.roots.config.output_path(), opts.out)
        node.call(mkdirp, path.dirname(output_path))
          .then(=> node.call(fs.writeFile, output_path, @contents))