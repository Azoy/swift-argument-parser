//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Echo

// FIXME: Cache the results somewhere
func findSubcommands(for type: Any.Type) -> [ParsableCommand.Type] {
  // This guard should be guaranteed to work because only structs, enums, and
  // classes can conform to this protocol. If that's not the case, something
  // went terribly wrong somewhere.
  guard let selfMetadata = reflect(type) as? TypeMetadata else {
    return []
  }
  
  let module = getModuleDescriptor(from: selfMetadata.contextDescriptor)
  
  // ParsableCommand is a protocol, thus referencing it in Swift as such
  // refers to the existential type, "any ParsableCommand".
  let parsableCommandMeta = reflect(
    ParsableCommand.self
  ) as! ExistentialMetadata
  
  // Since there is only one protocol associated with this existential type,
  // the first element is for sure to be here and refer to the actual
  // ParsableCommand protocol descriptor.
  let parsableCommand = parsableCommandMeta.protocols[0]
  
  let conformances = Echo.conformances[parsableCommand, default: [:]]
  let moduleConformances = conformances[module, default: []]
  
  // FIXME: Maybe we want to reserve some initial space here?
  var subcommands: [ParsableCommand.Type] = []
  
  // Look through every conformance to ParsableCommand within the module that
  // this ParsableCommand resides in looking for nested subcommands.
  for conformance in moduleConformances {
    // If we don't have a context descriptor, then an ObjC class somehow
    // conformed to a Swift protocol (not sure that's possible).
    guard let descriptor = conformance.contextDescriptor else {
      continue
    }
    
    // This is okay because modules can't conform to protocols which are
    // always the final parent before there is no other parent.
    let parent = descriptor.parent!
    
    // We're only intested in conformances where the parent is ourselves
    // (the parent ParsableCommand).
    guard parent.ptr == selfMetadata.contextDescriptor.ptr else {
      continue
    }
    
    // If a subcommand is generic, we can't add it as a default because we have
    // no idea what type substituion they want for the generic parameter.
    guard !descriptor.flags.isGeneric else {
      continue
    }
    
    // We found a subcommand! Use the access function to get the metadata for
    // it and add it to the list!
    let response = descriptor.accessor(.complete)
    let subcommand = response.type as! ParsableCommand.Type
    subcommands.append(subcommand)
  }
  
  return subcommands
}

// Helper to walk up the parent chain to eventually get the module that
// defined a ParsableCommand.
func getModuleDescriptor(from cd: ContextDescriptor) -> ModuleDescriptor {
  var parent = cd
  
  while let newParent = parent.parent {
    parent = newParent
  }
  
  return parent as! ModuleDescriptor
}
